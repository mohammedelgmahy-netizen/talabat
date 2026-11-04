-- =====================================================================
--  002_app_api.sql
--  طبقة الـ API اللي بيستخدمها تطبيق Flutter ولوحات التحكم (Next.js)
--  تتشغل بعد delivery_schema.sql مباشرة (SQL Editor في Supabase → Run)
--
--  المحتوى:
--   1) حماية أعمدة الطلبات والشحنات من التعديل المباشر
--   2) تحديث خوارزمية الإسناد: لا يُعاد إسناد الطلب لسائق رفضه + الإسناد الآلي
--   3) دوال القراءة اللي بترجع إحداثيات lat/lng بدل صيغة PostGIS الثنائية
--   4) العناوين، الأجهزة و FCM، المتجر، إلغاء الطلب من العميل
--   5) إحصائيات لوحات التحكم (أدمن / صاحب متجر / سائق)
--   6) Storage bucket للصور + Realtime لجداول إضافية
-- =====================================================================

set search_path = public, extensions;

-- Supabase بيمنحها افتراضياً؛ مكتوبة للتأكيد لأن بعض الدوال invoker وبتستخدم PostGIS
grant usage on schema extensions to anon, authenticated, service_role;


-- =====================================================================
-- 1) حماية الأعمدة
-- =====================================================================

-- صاحب المتجر يغيّر الحالة ووقت التحضير وسبب الإلغاء فقط (مش الأسعار ولا العميل)
create or replace function public.guard_order_columns()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is not null and pg_trigger_depth() = 1 and not public.is_admin() then
    if new.client_id            is distinct from old.client_id
       or new.store_id             is distinct from old.store_id
       or new.subtotal             is distinct from old.subtotal
       or new.delivery_fee         is distinct from old.delivery_fee
       or new.service_fee          is distinct from old.service_fee
       or new.discount_amount      is distinct from old.discount_amount
       or new.tax_amount           is distinct from old.tax_amount
       or new.commission_rate      is distinct from old.commission_rate
       or new.delivery_location    is distinct from old.delivery_location
       or new.delivery_address_text is distinct from old.delivery_address_text
       or new.payment_method       is distinct from old.payment_method
       or new.payment_status       is distinct from old.payment_status then
      raise exception 'غير مسموح بتعديل بيانات الفاتورة' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_orders_guard on public.orders;
create trigger trg_orders_guard before update on public.orders
  for each row execute function public.guard_order_columns();

-- السائق يغيّر حالة الشحنة وسبب الفشل وصورة الإثبات فقط
create or replace function public.guard_delivery_columns()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is not null and pg_trigger_depth() = 1 and not public.is_admin() then
    if new.order_id             is distinct from old.order_id
       or new.driver_id            is distinct from old.driver_id
       or new.driver_earning       is distinct from old.driver_earning
       or new.pickup_location      is distinct from old.pickup_location
       or new.dropoff_location     is distinct from old.dropoff_location
       or new.distance_to_store_m  is distinct from old.distance_to_store_m then
      raise exception 'غير مسموح بتعديل بيانات الشحنة' using errcode = '42501';
    end if;
    -- ملاحظة: التسليم نفسه محمي بالفعل في validate_delivery_status_transition (لازم OTP متحقق منه)
  end if;
  return new;
end;
$$;

drop trigger if exists trg_deliveries_guard on public.deliveries;
create trigger trg_deliveries_guard before update on public.deliveries
  for each row execute function public.guard_delivery_columns();


-- =====================================================================
-- 2) الإسناد: نفس خوارزمية الملف الأول مع إضافتين
--    أ) pg_trigger_depth() > 0 = استدعاء داخلي موثوق (من trigger) فيُسمح به
--    ب) لا نعيد الطلب لسائق سبق ورفضه أو فشل في توصيله
-- =====================================================================
create or replace function public.find_nearest_available_drivers(
  p_store_id          uuid,
  p_radius_km         numeric  default 5,
  p_limit             integer  default 10,
  p_max_location_age  interval default interval '2 minutes'
)
returns table (
  driver_id          uuid,
  full_name          text,
  phone              text,
  vehicle_type       public.vehicle_type,
  rating             numeric,
  distance_meters    integer,
  eta_minutes        integer,
  heading            numeric,
  latitude           double precision,
  longitude          double precision,
  last_location_at   timestamptz,
  active_deliveries  integer
)
language plpgsql stable security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_store_location geography;
begin
  if p_radius_km is null or p_radius_km <= 0 or p_radius_km > 50 then
    raise exception 'نصف قطر البحث يجب أن يكون بين 0 و 50 كم';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'عدد النتائج يجب أن يكون بين 1 و 100';
  end if;

  if auth.uid() is not null and pg_trigger_depth() = 0
     and not (public.is_admin() or public.owns_store(p_store_id)) then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;

  select s.location into v_store_location from public.stores s where s.id = p_store_id;
  if v_store_location is null then
    raise exception 'المتجر غير موجود: %', p_store_id;
  end if;

  return query
  with candidates as (
    select d.user_id, d.vehicle_type, d.rating, d.current_location, d.current_heading,
           d.last_location_at, d.max_concurrent_deliveries,
           st_distance(d.current_location, v_store_location) as dist_m
    from public.drivers d
    join public.profiles p on p.id = d.user_id and p.status = 'active'
    where d.availability = 'online'
      and d.is_verified
      and d.current_location is not null
      and d.last_location_at >= now() - p_max_location_age
      and st_dwithin(d.current_location, v_store_location, p_radius_km * 1000)
    order by d.current_location <-> v_store_location
    limit p_limit * 3
  ),
  with_load as (
    select c.*,
           (select count(*)::integer from public.deliveries dl
             where dl.driver_id = c.user_id
               and dl.status in ('assigned', 'accepted', 'arrived_at_store', 'picked_up', 'on_the_way', 'arrived_at_customer')
           ) as active_cnt
    from candidates c
  )
  select w.user_id, p.full_name, p.phone, w.vehicle_type, w.rating,
         round(w.dist_m)::integer,
         greatest(1, ceil((w.dist_m / 1000.0) / (case w.vehicle_type
                                                 when 'bicycle'    then 15
                                                 when 'motorcycle' then 30
                                                 when 'car'        then 25
                                                 when 'van'        then 22 end) * 60))::integer,
         w.current_heading,
         st_y(w.current_location::geometry),
         st_x(w.current_location::geometry),
         w.last_location_at,
         w.active_cnt
  from with_load w
  join public.profiles p on p.id = w.user_id
  where w.active_cnt < w.max_concurrent_deliveries
  order by w.dist_m asc, w.active_cnt asc, w.rating desc
  limit p_limit;
end;
$$;

create or replace function public.assign_nearest_driver(
  p_order_id  uuid,
  p_radius_km numeric default null
)
returns uuid
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_order       public.orders%rowtype;
  v_store_loc   geography;
  v_radius      numeric;
  v_candidate   record;
  v_locked      uuid;
  v_delivery_id uuid;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'الطلب غير موجود';
  end if;

  if auth.uid() is not null and pg_trigger_depth() = 0
     and not (public.is_admin() or public.owns_store(v_order.store_id)) then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;

  if v_order.status not in ('accepted', 'preparing', 'ready_for_pickup') then
    raise exception 'لا يمكن إسناد سائق لطلب حالته %', v_order.status;
  end if;

  if exists (select 1 from public.deliveries
             where order_id = p_order_id and status not in ('cancelled', 'failed')) then
    raise exception 'الطلب لديه شحنة نشطة بالفعل';
  end if;

  select s.location into v_store_loc from public.stores s where s.id = v_order.store_id;
  select coalesce(p_radius_km, ps.driver_search_radius_km) into v_radius from public.platform_settings ps;

  for v_candidate in
    select * from public.find_nearest_available_drivers(v_order.store_id, v_radius, 20)
  loop
    -- تخطي السائق اللي رفض نفس الطلب قبل كده
    continue when exists (select 1 from public.deliveries x
                           where x.order_id = p_order_id and x.driver_id = v_candidate.driver_id);

    select d.user_id into v_locked
      from public.drivers d
     where d.user_id = v_candidate.driver_id
       and d.availability = 'online'
     for update skip locked;

    if v_locked is not null then
      insert into public.deliveries (
        order_id, driver_id, status, pickup_location, dropoff_location,
        distance_to_store_m, driver_earning
      ) values (
        p_order_id, v_locked, 'assigned', v_store_loc, v_order.delivery_location,
        v_candidate.distance_meters, round(v_order.delivery_fee * 0.80, 2)
      )
      returning id into v_delivery_id;

      update public.drivers d
         set availability = 'busy'
       where d.user_id = v_locked
         and (select count(*) from public.deliveries x
               where x.driver_id = v_locked
                 and x.status in ('assigned', 'accepted', 'arrived_at_store', 'picked_up', 'on_the_way', 'arrived_at_customer')
             ) >= d.max_concurrent_deliveries;

      return v_delivery_id;
    end if;
  end loop;

  return null;
end;
$$;

-- إسناد آلي: أول ما المتجر يقبل الطلب، وكمان لو السائق رفض/ألغى الشحنة
create or replace function public.auto_assign_on_order_accept()
returns trigger
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
begin
  begin
    perform public.assign_nearest_driver(new.id);
  exception when others then
    raise notice 'auto assign skipped for %: %', new.id, sqlerrm;  -- لا نوقف قبول الطلب لو مفيش سائق
  end;
  return new;
end;
$$;

drop trigger if exists trg_orders_auto_assign on public.orders;
create trigger trg_orders_auto_assign after update of status on public.orders
  for each row when (new.status = 'accepted' and old.status = 'pending')
  execute function public.auto_assign_on_order_accept();

create or replace function public.auto_reassign_on_delivery_cancel()
returns trigger
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
begin
  if exists (select 1 from public.orders o
             where o.id = new.order_id and o.status in ('accepted', 'preparing', 'ready_for_pickup')) then
    begin
      perform public.assign_nearest_driver(new.order_id);
    exception when others then
      raise notice 'auto reassign skipped for %: %', new.order_id, sqlerrm;
    end;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_deliveries_auto_reassign on public.deliveries;
create trigger trg_deliveries_auto_reassign after update of status on public.deliveries
  for each row when (new.status = 'cancelled' and old.status in ('assigned', 'accepted', 'arrived_at_store'))
  execute function public.auto_reassign_on_delivery_cancel();

-- الطلبات المقبولة اللي ملهاش سائق: تتجدول كل دقيقة بـ pg_cron
-- select cron.schedule('retry-assign', '* * * * *', 'select public.retry_unassigned_orders()');
create or replace function public.retry_unassigned_orders()
returns integer
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_order_id uuid;
  v_assigned integer := 0;
begin
  for v_order_id in
    select o.id from public.orders o
     where o.status in ('accepted', 'preparing', 'ready_for_pickup')
       and not exists (select 1 from public.deliveries d
                        where d.order_id = o.id and d.status not in ('cancelled', 'failed'))
     order by o.accepted_at nulls last
     limit 200
  loop
    begin
      if public.assign_nearest_driver(v_order_id) is not null then
        v_assigned := v_assigned + 1;
      end if;
    exception when others then
      null;
    end;
  end loop;
  return v_assigned;
end;
$$;


-- =====================================================================
-- 3) المتاجر القريبة للعميل (مع رسوم التوصيل المتوقعة)
-- =====================================================================
create or replace function public.nearby_stores(
  p_latitude   double precision,
  p_longitude  double precision,
  p_search     text    default null,
  p_limit      integer default 50,
  p_offset     integer default 0
)
returns table (
  id                     uuid,
  name                   text,
  slug                   text,
  description            text,
  logo_url               text,
  cover_url              text,
  address_line           text,
  latitude               double precision,
  longitude              double precision,
  distance_km            numeric,
  delivery_fee           numeric,
  avg_prep_time_minutes  smallint,
  min_order_amount       numeric,
  rating                 numeric,
  rating_count           integer,
  is_open                boolean
)
language sql stable security definer
set search_path = public, extensions, pg_temp
as $$
  with me as (
    select st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)::geography as g
  )
  select s.id, s.name, s.slug, s.description, s.logo_url, s.cover_url, s.address_line,
         st_y(s.location::geometry), st_x(s.location::geometry),
         round((st_distance(s.location, me.g) / 1000.0)::numeric, 2),
         round(s.delivery_fee_base + s.delivery_fee_per_km * (st_distance(s.location, me.g) / 1000.0)::numeric, 2),
         s.avg_prep_time_minutes, s.min_order_amount, s.rating, s.rating_count, s.is_open
  from public.stores s, me
  where s.status = 'active'
    and st_dwithin(s.location, me.g, s.delivery_radius_km * 1000)
    and (p_search is null or p_search = '' or s.name ilike '%' || p_search || '%'
         or exists (select 1 from public.products p
                     where p.store_id = s.id and p.status = 'active' and p.name ilike '%' || p_search || '%'))
  order by s.is_open desc, s.location <-> me.g
  limit least(greatest(p_limit, 1), 100) offset greatest(p_offset, 0);
$$;


-- =====================================================================
-- 4) العناوين
-- =====================================================================
create or replace function public.my_addresses()
returns table (
  id uuid, label text, address_line text, building text, floor text, apartment text,
  landmark text, latitude double precision, longitude double precision, is_default boolean
)
language sql stable security definer
set search_path = public, extensions, pg_temp
as $$
  select a.id, a.label, a.address_line, a.building, a.floor, a.apartment, a.landmark,
         st_y(a.location::geometry), st_x(a.location::geometry), a.is_default
  from public.user_addresses a
  where a.user_id = auth.uid()
  order by a.is_default desc, a.created_at desc;
$$;

create or replace function public.save_address(
  p_id            uuid,
  p_label         text,
  p_address_line  text,
  p_building      text,
  p_floor         text,
  p_apartment     text,
  p_landmark      text,
  p_latitude      double precision,
  p_longitude     double precision,
  p_is_default    boolean default false
)
returns uuid
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
  v_loc geography := st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)::geography;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول' using errcode = '42501';
  end if;
  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'إحداثيات غير صحيحة';
  end if;

  -- أول عنوان يبقى افتراضي تلقائياً
  if not exists (select 1 from public.user_addresses where user_id = v_uid) then
    p_is_default := true;
  end if;

  if p_is_default then
    update public.user_addresses set is_default = false where user_id = v_uid and is_default;
  end if;

  if p_id is null then
    insert into public.user_addresses (user_id, label, address_line, building, floor, apartment, landmark, location, is_default)
    values (v_uid, coalesce(nullif(p_label, ''), 'home'), p_address_line, p_building, p_floor, p_apartment, p_landmark, v_loc, p_is_default)
    returning id into v_id;
  else
    update public.user_addresses
       set label = coalesce(nullif(p_label, ''), 'home'), address_line = p_address_line,
           building = p_building, floor = p_floor, apartment = p_apartment, landmark = p_landmark,
           location = v_loc, is_default = p_is_default
     where id = p_id and user_id = v_uid
    returning id into v_id;
    if v_id is null then
      raise exception 'العنوان غير موجود';
    end if;
  end if;
  return v_id;
end;
$$;


-- =====================================================================
-- 5) تسجيل الجهاز و FCM Token (يُستدعى بعد تسجيل الدخول وعند تجديد الرمز)
-- =====================================================================
create or replace function public.register_device(
  p_device_id    text,
  p_platform     public.device_platform,
  p_fcm_token    text default null,
  p_device_model text default null,
  p_app_version  text default null
)
returns uuid
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid        uuid := auth.uid();
  v_session_id uuid;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول' using errcode = '42501';
  end if;

  insert into public.user_sessions (user_id, device_id, device_model, platform, app_version, last_seen_at, revoked_at)
  values (v_uid, p_device_id, p_device_model, p_platform, p_app_version, now(), null)
  on conflict (user_id, device_id) do update
     set device_model = excluded.device_model, platform = excluded.platform,
         app_version = excluded.app_version, last_seen_at = now(), revoked_at = null
  returning id into v_session_id;

  if p_fcm_token is not null and char_length(p_fcm_token) >= 20 then
    -- نفس الرمز ممكن ينتقل لمستخدم تاني على نفس الجهاز
    insert into public.fcm_tokens (user_id, session_id, token, platform, is_active, last_used_at)
    values (v_uid, v_session_id, p_fcm_token, p_platform, true, now())
    on conflict (token) do update
       set user_id = v_uid, session_id = v_session_id, platform = excluded.platform,
           is_active = true, last_used_at = now();
    -- أي رمز قديم لنفس الجلسة يتعطل
    update public.fcm_tokens set is_active = false
     where session_id = v_session_id and token <> p_fcm_token and is_active;
  end if;

  return v_session_id;
end;
$$;

create or replace function public.sign_out_device(p_device_id text)
returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  update public.user_sessions set revoked_at = now()
   where user_id = auth.uid() and device_id = p_device_id;
  update public.fcm_tokens set is_active = false
   where user_id = auth.uid()
     and session_id in (select id from public.user_sessions where user_id = auth.uid() and device_id = p_device_id);
end;
$$;


-- =====================================================================
-- 6) تفاصيل الطلب الكاملة لأي طرف فيه (عميل / متجر / سائق / أدمن)
--    ترجع أسماء وأرقام الأطراف (اللي الـ RLS بيخفيها) لمن له حق فقط
-- =====================================================================
create or replace function public.get_order_details(p_order_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_result jsonb;
begin
  if not public.can_view_order(p_order_id) then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'id', o.id,
    'order_number', o.order_number,
    'status', o.status,
    'subtotal', o.subtotal,
    'delivery_fee', o.delivery_fee,
    'service_fee', o.service_fee,
    'discount_amount', o.discount_amount,
    'tax_amount', o.tax_amount,
    'total_amount', o.total_amount,
    'commission_amount', o.commission_amount,
    'store_payout', o.store_payout,
    'distance_km', o.distance_km,
    'payment_method', o.payment_method,
    'payment_status', o.payment_status,
    'customer_notes', o.customer_notes,
    'estimated_prep_minutes', o.estimated_prep_minutes,
    'delivery_address_text', o.delivery_address_text,
    'delivery_latitude', st_y(o.delivery_location::geometry),
    'delivery_longitude', st_x(o.delivery_location::geometry),
    'placed_at', o.placed_at,
    'accepted_at', o.accepted_at,
    'ready_at', o.ready_at,
    'picked_up_at', o.picked_up_at,
    'delivered_at', o.delivered_at,
    'cancelled_at', o.cancelled_at,
    'cancellation_reason', o.cancellation_reason,
    'client', jsonb_build_object('id', c.id, 'full_name', c.full_name, 'phone', c.phone),
    'store', jsonb_build_object(
      'id', s.id, 'name', s.name, 'phone', s.phone, 'logo_url', s.logo_url,
      'address_line', s.address_line,
      'latitude', st_y(s.location::geometry), 'longitude', st_x(s.location::geometry)
    ),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', i.id, 'product_id', i.product_id, 'product_name', i.product_name,
               'unit_price', i.unit_price, 'quantity', i.quantity, 'line_total', i.line_total, 'notes', i.notes)
             order by i.created_at)
      from public.order_items i where i.order_id = o.id), '[]'::jsonb),
    'history', coalesce((
      select jsonb_agg(jsonb_build_object('from', h.from_status, 'to', h.to_status, 'note', h.note, 'at', h.created_at)
             order by h.created_at)
      from public.order_status_history h where h.order_id = o.id), '[]'::jsonb),
    'delivery', (
      select jsonb_build_object(
               'id', d.id, 'status', d.status, 'driver_id', d.driver_id,
               'driver_name', dp.full_name, 'driver_phone', dp.phone,
               'vehicle_type', dr.vehicle_type, 'vehicle_plate', dr.vehicle_plate, 'driver_rating', dr.rating,
               'driver_latitude', st_y(dr.current_location::geometry),
               'driver_longitude', st_x(dr.current_location::geometry),
               'driver_heading', dr.current_heading,
               'driver_earning', d.driver_earning,
               'assigned_at', d.assigned_at, 'accepted_at', d.accepted_at,
               'picked_up_at', d.picked_up_at, 'delivered_at', d.delivered_at)
      from public.deliveries d
      join public.drivers dr on dr.user_id = d.driver_id
      join public.profiles dp on dp.id = d.driver_id
      where d.order_id = o.id
      order by (d.status in ('cancelled', 'failed')), d.assigned_at desc
      limit 1)
  )
  into v_result
  from public.orders o
  join public.profiles c on c.id = o.client_id
  join public.stores s on s.id = o.store_id
  where o.id = p_order_id;

  return v_result;
end;
$$;

-- العميل يلغي طلبه طالما المتجر لم يقبله بعد
create or replace function public.cancel_my_order(p_order_id uuid, p_reason text default null)
returns void
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found or v_order.client_id is distinct from auth.uid() then
    raise exception 'الطلب غير موجود' using errcode = '42501';
  end if;
  if v_order.status <> 'pending' then
    raise exception 'لا يمكن إلغاء الطلب بعد قبوله من المتجر';
  end if;
  update public.orders
     set status = 'cancelled', cancellation_reason = coalesce(nullif(p_reason, ''), 'ألغاه العميل')
   where id = p_order_id;
end;
$$;


-- =====================================================================
-- 7) المتجر: إنشاء/تعديل بإحداثيات + قراءة متاجري
-- =====================================================================
create or replace function public.save_my_store(
  p_id                    uuid,
  p_name                  text,
  p_slug                  text,
  p_description           text,
  p_phone                 text,
  p_logo_url              text,
  p_cover_url             text,
  p_address_line          text,
  p_latitude              double precision,
  p_longitude             double precision,
  p_delivery_radius_km    numeric,
  p_avg_prep_time_minutes smallint,
  p_min_order_amount      numeric,
  p_delivery_fee_base     numeric,
  p_delivery_fee_per_km   numeric
)
returns uuid
language plpgsql security invoker   -- invoker: الـ RLS والـ guard triggers يتطبقوا عادي
set search_path = public, extensions, pg_temp
as $$
declare
  v_id  uuid;
  v_loc geography := st_setsrid(st_makepoint(p_longitude, p_latitude), 4326)::geography;
begin
  if p_id is null then
    insert into public.stores (owner_id, name, slug, description, phone, logo_url, cover_url, address_line,
                               location, delivery_radius_km, avg_prep_time_minutes, min_order_amount,
                               delivery_fee_base, delivery_fee_per_km)
    values (auth.uid(), p_name, lower(p_slug), p_description, nullif(p_phone, ''), p_logo_url, p_cover_url, p_address_line,
            v_loc, p_delivery_radius_km, p_avg_prep_time_minutes, p_min_order_amount,
            p_delivery_fee_base, p_delivery_fee_per_km)
    returning id into v_id;
  else
    update public.stores
       set name = p_name, slug = lower(p_slug), description = p_description, phone = nullif(p_phone, ''),
           logo_url = p_logo_url, cover_url = p_cover_url, address_line = p_address_line, location = v_loc,
           delivery_radius_km = p_delivery_radius_km, avg_prep_time_minutes = p_avg_prep_time_minutes,
           min_order_amount = p_min_order_amount, delivery_fee_base = p_delivery_fee_base,
           delivery_fee_per_km = p_delivery_fee_per_km
     where id = p_id
    returning id into v_id;
    if v_id is null then
      raise exception 'المتجر غير موجود' using errcode = '42501';
    end if;
  end if;
  return v_id;
end;
$$;

create or replace function public.store_location(p_store_id uuid)
returns table (latitude double precision, longitude double precision)
language sql stable
set search_path = public, extensions, pg_temp
as $$
  select st_y(location::geometry), st_x(location::geometry) from public.stores where id = p_store_id;
$$;


-- =====================================================================
-- 8) إحصائيات لوحات التحكم
-- =====================================================================

-- إحصائيات متجر واحد في فترة
create or replace function public.store_dashboard_stats(
  p_store_id uuid,
  p_from     timestamptz default date_trunc('day', now()) - interval '29 days',
  p_to       timestamptz default now()
)
returns jsonb
language plpgsql stable security definer
set search_path = public, pg_temp
as $$
declare
  v jsonb;
begin
  if not (public.is_admin() or public.owns_store(p_store_id)) then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;

  with o as (
    select * from public.orders where store_id = p_store_id and placed_at between p_from and p_to
  )
  select jsonb_build_object(
    'orders_total',      (select count(*) from o),
    'orders_delivered',  (select count(*) from o where status = 'delivered'),
    'orders_cancelled',  (select count(*) from o where status in ('cancelled', 'rejected')),
    'orders_active',     (select count(*) from public.orders
                           where store_id = p_store_id and status not in ('delivered', 'cancelled', 'rejected')),
    'gross_sales',       (select coalesce(sum(subtotal), 0) from o where status = 'delivered'),
    'commission',        (select coalesce(sum(commission_amount), 0) from o where status = 'delivered'),
    'payout',            (select coalesce(sum(store_payout), 0) from o where status = 'delivered'),
    'avg_order_value',   (select coalesce(round(avg(subtotal), 2), 0) from o where status = 'delivered'),
    'avg_prep_minutes',  (select coalesce(round(avg(extract(epoch from (ready_at - accepted_at)) / 60)::numeric, 1), 0)
                            from o where ready_at is not null and accepted_at is not null),
    'daily', coalesce((
      select jsonb_agg(jsonb_build_object('day', d.day, 'orders', d.cnt, 'sales', d.sales) order by d.day)
      from (select date_trunc('day', placed_at)::date as day, count(*) as cnt,
                   coalesce(sum(subtotal) filter (where status = 'delivered'), 0) as sales
              from o group by 1) d), '[]'::jsonb),
    'top_products', coalesce((
      select jsonb_agg(t order by t.qty desc)
      from (select i.product_name as name, sum(i.quantity) as qty, sum(i.line_total) as revenue
              from public.order_items i join o on o.id = i.order_id
             where o.status = 'delivered'
             group by i.product_name order by 2 desc limit 10) t), '[]'::jsonb)
  ) into v;
  return v;
end;
$$;

-- إحصائيات المنصة كاملة (أدمن)
create or replace function public.admin_dashboard_stats(
  p_from timestamptz default date_trunc('day', now()) - interval '29 days',
  p_to   timestamptz default now()
)
returns jsonb
language plpgsql stable security definer
set search_path = public, pg_temp
as $$
declare
  v jsonb;
begin
  if not public.is_admin() then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;

  with o as (select * from public.orders where placed_at between p_from and p_to)
  select jsonb_build_object(
    'orders_total',       (select count(*) from o),
    'orders_delivered',   (select count(*) from o where status = 'delivered'),
    'orders_cancelled',   (select count(*) from o where status in ('cancelled', 'rejected')),
    'orders_active',      (select count(*) from public.orders where status not in ('delivered', 'cancelled', 'rejected')),
    'gmv',                (select coalesce(sum(total_amount), 0) from o where status = 'delivered'),
    'commission',         (select coalesce(sum(commission_amount), 0) from o where status = 'delivered'),
    'service_fees',       (select coalesce(sum(service_fee), 0) from o where status = 'delivered'),
    'avg_delivery_minutes', (select coalesce(round(avg(extract(epoch from (delivered_at - placed_at)) / 60)::numeric, 1), 0)
                               from o where delivered_at is not null),
    'clients',            (select count(*) from public.profiles where role = 'client'),
    'drivers_total',      (select count(*) from public.drivers),
    'drivers_online',     (select count(*) from public.drivers where availability in ('online', 'busy')),
    'drivers_unverified', (select count(*) from public.drivers where not is_verified),
    'stores_active',      (select count(*) from public.stores where status = 'active'),
    'stores_pending',     (select count(*) from public.stores where status = 'pending_approval'),
    'daily', coalesce((
      select jsonb_agg(jsonb_build_object('day', d.day, 'orders', d.cnt, 'gmv', d.gmv, 'commission', d.comm) order by d.day)
      from (select date_trunc('day', placed_at)::date as day, count(*) as cnt,
                   coalesce(sum(total_amount) filter (where status = 'delivered'), 0) as gmv,
                   coalesce(sum(commission_amount) filter (where status = 'delivered'), 0) as comm
              from o group by 1) d), '[]'::jsonb),
    'top_stores', coalesce((
      select jsonb_agg(t order by t.sales desc)
      from (select s.id, s.name, count(*) as orders, sum(o.subtotal) as sales
              from o join public.stores s on s.id = o.store_id
             where o.status = 'delivered'
             group by s.id, s.name order by 4 desc limit 10) t), '[]'::jsonb)
  ) into v;
  return v;
end;
$$;

-- خريطة حية للأدمن: السائقين المتصلين + الطلبات النشطة
create or replace function public.admin_live_map()
returns jsonb
language plpgsql stable security definer
set search_path = public, extensions, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'drivers', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', d.user_id, 'name', p.full_name, 'availability', d.availability,
               'vehicle_type', d.vehicle_type, 'heading', d.current_heading,
               'latitude', st_y(d.current_location::geometry), 'longitude', st_x(d.current_location::geometry),
               'last_location_at', d.last_location_at))
      from public.drivers d join public.profiles p on p.id = d.user_id
      where d.availability <> 'offline' and d.current_location is not null), '[]'::jsonb),
    'orders', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', o.id, 'order_number', o.order_number, 'status', o.status, 'store', s.name,
               'store_latitude', st_y(s.location::geometry), 'store_longitude', st_x(s.location::geometry),
               'latitude', st_y(o.delivery_location::geometry), 'longitude', st_x(o.delivery_location::geometry)))
      from public.orders o join public.stores s on s.id = o.store_id
      where o.status not in ('delivered', 'cancelled', 'rejected')), '[]'::jsonb)
  );
end;
$$;

-- قائمة المستخدمين للأدمن مع بيانات السائق إن وُجدت
create or replace function public.admin_list_users(
  p_role   public.user_role default null,
  p_search text default null,
  p_limit  integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid, role public.user_role, full_name text, phone text, email text, status public.account_status,
  created_at timestamptz, driver_verified boolean, driver_availability public.driver_availability,
  vehicle_type public.vehicle_type, total_deliveries integer, total_count bigint
)
language plpgsql stable security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;
  return query
  select p.id, p.role, p.full_name, p.phone, p.email, p.status, p.created_at,
         d.is_verified, d.availability, d.vehicle_type, d.total_deliveries,
         count(*) over ()
  from public.profiles p
  left join public.drivers d on d.user_id = p.id
  where (p_role is null or p.role = p_role)
    and (p_search is null or p_search = '' or p.full_name ilike '%' || p_search || '%'
         or p.phone ilike '%' || p_search || '%' or p.email ilike '%' || p_search || '%')
  order by p.created_at desc
  limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0);
end;
$$;

-- ملخص أرباح السائق
create or replace function public.my_driver_summary()
returns jsonb
language sql stable security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'today_earnings',     coalesce(sum(driver_earning) filter (where status = 'delivered' and delivered_at >= date_trunc('day', now())), 0),
    'today_deliveries',   count(*) filter (where status = 'delivered' and delivered_at >= date_trunc('day', now())),
    'week_earnings',      coalesce(sum(driver_earning) filter (where status = 'delivered' and delivered_at >= date_trunc('week', now())), 0),
    'week_deliveries',    count(*) filter (where status = 'delivered' and delivered_at >= date_trunc('week', now())),
    'total_earnings',     coalesce(sum(driver_earning) filter (where status = 'delivered'), 0),
    'total_deliveries',   count(*) filter (where status = 'delivered'),
    'cash_to_collect',    coalesce((select sum(o.total_amount) from public.deliveries d2
                                     join public.orders o on o.id = d2.order_id
                                    where d2.driver_id = auth.uid() and o.payment_method = 'cash'
                                      and d2.status in ('picked_up', 'on_the_way', 'arrived_at_customer')), 0)
  )
  from public.deliveries
  where driver_id = auth.uid();
$$;


-- =====================================================================
-- 9) صلاحيات تنفيذ الدوال الجديدة
-- =====================================================================
revoke execute on function public.guard_order_columns()                 from public, anon, authenticated;
revoke execute on function public.guard_delivery_columns()              from public, anon, authenticated;
revoke execute on function public.auto_assign_on_order_accept()         from public, anon, authenticated;
revoke execute on function public.auto_reassign_on_delivery_cancel()    from public, anon, authenticated;
revoke execute on function public.retry_unassigned_orders()             from public, anon, authenticated;
grant  execute on function public.retry_unassigned_orders()             to service_role;

grant execute on function public.nearby_stores(double precision, double precision, text, integer, integer) to anon, authenticated;
grant execute on function public.store_location(uuid) to anon, authenticated;

revoke execute on function public.my_addresses()                         from public, anon;
revoke execute on function public.save_address(uuid, text, text, text, text, text, text, double precision, double precision, boolean) from public, anon;
revoke execute on function public.register_device(text, public.device_platform, text, text, text) from public, anon;
revoke execute on function public.sign_out_device(text)                  from public, anon;
revoke execute on function public.get_order_details(uuid)                from public, anon;
revoke execute on function public.cancel_my_order(uuid, text)            from public, anon;
revoke execute on function public.save_my_store(uuid, text, text, text, text, text, text, text, double precision, double precision, numeric, smallint, numeric, numeric, numeric) from public, anon;
revoke execute on function public.store_dashboard_stats(uuid, timestamptz, timestamptz) from public, anon;
revoke execute on function public.admin_dashboard_stats(timestamptz, timestamptz)       from public, anon;
revoke execute on function public.admin_live_map()                       from public, anon;
revoke execute on function public.admin_list_users(public.user_role, text, integer, integer) from public, anon;
revoke execute on function public.my_driver_summary()                    from public, anon;

grant execute on function public.my_addresses()                         to authenticated;
grant execute on function public.save_address(uuid, text, text, text, text, text, text, double precision, double precision, boolean) to authenticated;
grant execute on function public.register_device(text, public.device_platform, text, text, text) to authenticated;
grant execute on function public.sign_out_device(text)                  to authenticated;
grant execute on function public.get_order_details(uuid)                to authenticated;
grant execute on function public.cancel_my_order(uuid, text)            to authenticated;
grant execute on function public.save_my_store(uuid, text, text, text, text, text, text, text, double precision, double precision, numeric, smallint, numeric, numeric, numeric) to authenticated;
grant execute on function public.store_dashboard_stats(uuid, timestamptz, timestamptz) to authenticated;
grant execute on function public.admin_dashboard_stats(timestamptz, timestamptz)       to authenticated;
grant execute on function public.admin_live_map()                       to authenticated;
grant execute on function public.admin_list_users(public.user_role, text, integer, integer) to authenticated;
grant execute on function public.my_driver_summary()                    to authenticated;


-- =====================================================================
-- 10) Realtime لجداول إضافية + Storage للصور
-- =====================================================================
do $$
declare
  t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['order_status_history', 'stores'] loop
      if not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;

-- bucket عام للصور: المسار stores/<store_id>/... لصاحب المتجر، و avatars/<user_id>/... لأي مستخدم
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('media', 'media', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
    on conflict (id) do nothing;

    execute $p$drop policy if exists media_read on storage.objects$p$;
    execute $p$create policy media_read on storage.objects for select to anon, authenticated
      using (bucket_id = 'media')$p$;

    execute $p$drop policy if exists media_write on storage.objects$p$;
    execute $p$create policy media_write on storage.objects for insert to authenticated
      with check (bucket_id = 'media' and (
        ((storage.foldername(name))[1] = 'stores' and public.owns_store(((storage.foldername(name))[2])::uuid))
        or ((storage.foldername(name))[1] = 'avatars' and (storage.foldername(name))[2] = auth.uid()::text)
        or public.is_admin()))$p$;

    execute $p$drop policy if exists media_modify on storage.objects$p$;
    execute $p$create policy media_modify on storage.objects for update to authenticated
      using (bucket_id = 'media' and (owner = auth.uid() or public.is_admin()))$p$;

    execute $p$drop policy if exists media_delete on storage.objects$p$;
    execute $p$create policy media_delete on storage.objects for delete to authenticated
      using (bucket_id = 'media' and (owner = auth.uid() or public.is_admin()))$p$;
  end if;
end $$;

-- =====================================================================
-- نهاية الملف
-- =====================================================================
