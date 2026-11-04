-- =====================================================================
--  قاعدة بيانات تطبيق التوصيل (Delivery & Logistics Platform)
--  المنصة: Supabase (PostgreSQL 15+) + PostGIS + Realtime
--  طريقة التشغيل: انسخ الملف بالكامل في SQL Editor في Supabase واضغط Run
--  الملف idempotent قدر الإمكان (if not exists / or replace) لكنه مصمم
--  للتشغيل مرة واحدة على مشروع جديد.
-- =====================================================================


-- =====================================================================
-- 0) الإضافات (Extensions)
--    في Supabase الإضافات تُثبَّت في سكيمة extensions الموجودة في الـ search_path
-- =====================================================================
create schema if not exists extensions;
create extension if not exists postgis  with schema extensions;  -- المواقع الجغرافية
create extension if not exists pgcrypto with schema extensions;  -- تشفير رمز الـ OTP
create extension if not exists pg_trgm  with schema extensions;  -- البحث النصي السريع

set search_path = public, extensions;


-- =====================================================================
-- 1) الأنواع (Enums)
-- =====================================================================
do $$ begin
  create type public.user_role as enum ('client', 'driver', 'store_owner', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.account_status as enum ('active', 'suspended', 'banned', 'deleted');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.device_platform as enum ('android', 'ios', 'web');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.store_status as enum ('pending_approval', 'active', 'suspended', 'closed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.product_status as enum ('active', 'out_of_stock', 'hidden', 'archived');
exception when duplicate_object then null; end $$;

-- حالات الطلب من وجهة نظر العميل والمتجر
do $$ begin
  create type public.order_status as enum (
    'pending',           -- تم الإنشاء وفي انتظار قبول المتجر
    'accepted',          -- المتجر قبل الطلب
    'preparing',         -- جاري التحضير
    'ready_for_pickup',  -- جاهز لاستلام السائق
    'picked_up',         -- السائق استلم الطلب من المتجر
    'on_the_way',        -- في الطريق للعميل
    'delivered',         -- تم التسليم (بعد التحقق من الـ OTP)
    'rejected',          -- المتجر رفض الطلب
    'cancelled'          -- تم الإلغاء
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.payment_method as enum ('cash', 'card', 'wallet');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.payment_status as enum ('pending', 'authorized', 'paid', 'failed', 'refunded');
exception when duplicate_object then null; end $$;

-- حالات التوصيل من وجهة نظر السائق
do $$ begin
  create type public.delivery_status as enum (
    'assigned',             -- تم إسناد الشحنة للسائق
    'accepted',             -- السائق وافق
    'arrived_at_store',     -- وصل للمتجر
    'picked_up',            -- استلم الطلب
    'on_the_way',           -- في الطريق
    'arrived_at_customer',  -- وصل عند العميل
    'delivered',            -- تم التسليم بالـ OTP
    'failed',               -- فشل التسليم
    'cancelled'             -- ألغيت أو رفضها السائق
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.driver_availability as enum ('offline', 'online', 'busy', 'on_break');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.vehicle_type as enum ('bicycle', 'motorcycle', 'car', 'van');
exception when duplicate_object then null; end $$;


-- =====================================================================
-- 2) دوال مساعدة عامة
-- =====================================================================

-- تحديث updated_at تلقائياً عند أي تعديل
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;


-- =====================================================================
-- 3) المستخدمون (Users) والجلسات و FCM Tokens
--    المصادقة نفسها تتم عن طريق auth.users الخاص بـ Supabase،
--    وجدول profiles يحمل الدور والبيانات الإضافية بعلاقة 1:1
-- =====================================================================
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  role         public.user_role      not null default 'client',
  full_name    text                  not null check (char_length(full_name) between 2 and 120),
  phone        text                  unique check (phone ~ '^\+?[0-9]{8,15}$'),
  email        text                  unique check (email is null or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  avatar_url   text,
  status       public.account_status not null default 'active',
  locale       text                  not null default 'ar' check (locale in ('ar', 'en')),
  created_at   timestamptz           not null default now(),
  updated_at   timestamptz           not null default now()
);
comment on table public.profiles is 'بيانات المستخدمين وأدوارهم (عميل، سائق، صاحب متجر، أدمن)';

-- جلسات الأجهزة: كل جهاز مسجل دخول له صف هنا (لإدارة تسجيل الخروج من الأجهزة)
create table if not exists public.user_sessions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  device_id     text not null check (char_length(device_id) between 3 and 200),
  device_model  text,
  platform      public.device_platform not null,
  app_version   text,
  ip_address    inet,
  user_agent    text,
  last_seen_at  timestamptz not null default now(),
  revoked_at    timestamptz,
  created_at    timestamptz not null default now(),
  constraint user_sessions_user_device_uk unique (user_id, device_id)
);
comment on table public.user_sessions is 'جلسات المستخدم على كل جهاز';

-- رموز الإشعارات (Firebase Cloud Messaging)
create table if not exists public.fcm_tokens (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  session_id    uuid references public.user_sessions (id) on delete cascade,
  token         text not null unique check (char_length(token) between 20 and 4096),
  platform      public.device_platform not null,
  is_active     boolean not null default true,
  last_used_at  timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on table public.fcm_tokens is 'رموز FCM لإرسال الإشعارات لكل جهاز';

-- عناوين العملاء
create table if not exists public.user_addresses (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles (id) on delete cascade,
  label          text not null default 'home' check (char_length(label) between 1 and 50),
  address_line   text not null,
  building       text,
  floor          text,
  apartment      text,
  landmark       text,
  location       geography(Point, 4326) not null,
  is_default     boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
comment on table public.user_addresses is 'عناوين التوصيل الخاصة بالعملاء';

-- بيانات السائقين (امتداد لـ profiles لمن دوره driver)
create table if not exists public.drivers (
  user_id                    uuid primary key references public.profiles (id) on delete cascade,
  vehicle_type               public.vehicle_type not null default 'motorcycle',
  vehicle_plate              text unique,
  license_number             text unique,
  national_id                text unique,
  availability               public.driver_availability not null default 'offline',
  is_verified                boolean not null default false,
  max_concurrent_deliveries  smallint not null default 1 check (max_concurrent_deliveries between 1 and 5),
  rating                     numeric(3,2) not null default 5.00 check (rating between 0 and 5),
  total_deliveries           integer not null default 0 check (total_deliveries >= 0),
  -- آخر موقع معروف (نسخة مختصرة من driver_locations لتسريع البحث الجغرافي)
  current_location           geography(Point, 4326),
  current_heading            numeric(5,2) check (current_heading >= 0 and current_heading < 360),
  last_location_at           timestamptz,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now()
);
comment on table public.drivers is 'بيانات السائقين وحالة التوفر وآخر موقع';


-- =====================================================================
-- 4) المتاجر (Stores)
-- =====================================================================
create table if not exists public.stores (
  id                     uuid primary key default gen_random_uuid(),
  owner_id               uuid not null references public.profiles (id) on delete restrict,
  name                   text not null check (char_length(name) between 2 and 120),
  slug                   text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  description            text,
  phone                  text check (phone ~ '^\+?[0-9]{8,15}$'),
  logo_url               text,
  cover_url              text,
  address_line           text not null,
  location               geography(Point, 4326) not null,              -- موقع المتجر GIS Point
  delivery_radius_km     numeric(5,2) not null default 7.00 check (delivery_radius_km > 0 and delivery_radius_km <= 50),
  commission_rate        numeric(5,2) not null default 15.00 check (commission_rate between 0 and 100), -- نسبة عمولة المنصة %
  avg_prep_time_minutes  smallint not null default 20 check (avg_prep_time_minutes between 1 and 240),     -- وقت التحضير
  min_order_amount       numeric(10,2) not null default 0 check (min_order_amount >= 0),
  delivery_fee_base      numeric(10,2) not null default 10.00 check (delivery_fee_base >= 0),
  delivery_fee_per_km    numeric(10,2) not null default 2.00 check (delivery_fee_per_km >= 0),
  status                 public.store_status not null default 'pending_approval',
  is_open                boolean not null default false,
  rating                 numeric(3,2) not null default 0 check (rating between 0 and 5),
  rating_count           integer not null default 0 check (rating_count >= 0),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
comment on column public.stores.commission_rate is 'نسبة عمولة المنصة من قيمة المنتجات (Subtotal) بالنسبة المئوية';

-- مواعيد عمل المتجر (0 = الأحد ... 6 = السبت)
create table if not exists public.store_working_hours (
  id           uuid primary key default gen_random_uuid(),
  store_id     uuid not null references public.stores (id) on delete cascade,
  day_of_week  smallint not null check (day_of_week between 0 and 6),
  open_time    time not null,
  close_time   time not null,
  constraint store_working_hours_time_ck check (open_time <> close_time),
  constraint store_working_hours_uk unique (store_id, day_of_week, open_time)
);


-- =====================================================================
-- 5) الأقسام والمنتجات (Categories & Products)
-- =====================================================================
create table if not exists public.categories (
  id          uuid primary key default gen_random_uuid(),
  store_id    uuid not null references public.stores (id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 80),
  image_url   text,
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint categories_store_name_uk unique (store_id, name),
  -- مطلوب لعمل FK مركب يضمن أن القسم تابع لنفس متجر المنتج
  constraint categories_id_store_uk unique (id, store_id)
);

create table if not exists public.products (
  id                    uuid primary key default gen_random_uuid(),
  store_id              uuid not null references public.stores (id) on delete cascade,
  category_id           uuid,
  name                  text not null check (char_length(name) between 1 and 150),
  description           text,
  image_url             text,
  price                 numeric(10,2) not null check (price >= 0),
  discounted_price      numeric(10,2) check (discounted_price >= 0),
  status                public.product_status not null default 'active',
  prep_time_minutes     smallint check (prep_time_minutes between 1 and 240),
  calories              integer check (calories >= 0),
  sort_order            integer not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint products_discount_ck check (discounted_price is null or discounted_price < price),
  -- القسم لازم يكون من نفس المتجر
  constraint products_category_same_store_fk
    foreign key (category_id, store_id) references public.categories (id, store_id) on delete set null (category_id)
);
comment on column public.products.discounted_price is 'سعر بعد الخصم، يجب أن يكون أقل من السعر الأصلي';


-- =====================================================================
-- 6) إعدادات المنصة (صف واحد فقط)
-- =====================================================================
create table if not exists public.platform_settings (
  id                    boolean primary key default true check (id),  -- يضمن وجود صف واحد فقط
  service_fee           numeric(10,2) not null default 3.00 check (service_fee >= 0),
  tax_rate              numeric(5,2)  not null default 0.00 check (tax_rate between 0 and 100),
  otp_ttl_minutes       smallint      not null default 120 check (otp_ttl_minutes between 5 and 1440),
  otp_max_attempts      smallint      not null default 5 check (otp_max_attempts between 1 and 10),
  driver_search_radius_km numeric(5,2) not null default 5.00 check (driver_search_radius_km > 0),
  updated_at            timestamptz   not null default now()
);
insert into public.platform_settings (id) values (true) on conflict (id) do nothing;


-- =====================================================================
-- 7) الطلبات وعناصرها (Orders & Order_Items)
-- =====================================================================
create table if not exists public.orders (
  id                     uuid primary key default gen_random_uuid(),
  order_number           bigint generated always as identity (start with 100001) unique,  -- رقم الفاتورة الظاهر
  client_id              uuid not null references public.profiles (id) on delete restrict,
  store_id               uuid not null references public.stores (id) on delete restrict,
  delivery_address_id    uuid references public.user_addresses (id) on delete set null,
  -- نسخة ثابتة من العنوان وقت الطلب (لو العميل عدل/حذف العنوان لاحقاً)
  delivery_address_text  text not null,
  delivery_location      geography(Point, 4326) not null,
  status                 public.order_status not null default 'pending',
  -- الفاتورة
  subtotal               numeric(10,2) not null check (subtotal >= 0),
  delivery_fee           numeric(10,2) not null default 0 check (delivery_fee >= 0),
  service_fee            numeric(10,2) not null default 0 check (service_fee >= 0),
  discount_amount        numeric(10,2) not null default 0 check (discount_amount >= 0),
  tax_amount             numeric(10,2) not null default 0 check (tax_amount >= 0),
  total_amount           numeric(10,2) generated always as
                           (subtotal + delivery_fee + service_fee + tax_amount - discount_amount) stored,
  -- العمولة (نسخة ثابتة من نسبة المتجر وقت الطلب)
  commission_rate        numeric(5,2) not null check (commission_rate between 0 and 100),
  commission_amount      numeric(10,2) generated always as (round(subtotal * commission_rate / 100, 2)) stored,
  store_payout           numeric(10,2) generated always as (subtotal - round(subtotal * commission_rate / 100, 2)) stored,
  distance_km            numeric(6,2) check (distance_km >= 0),
  payment_method         public.payment_method not null default 'cash',
  payment_status         public.payment_status not null default 'pending',
  customer_notes         text check (char_length(customer_notes) <= 500),
  estimated_prep_minutes smallint check (estimated_prep_minutes between 1 and 240),
  -- توقيتات دورة حياة الطلب
  placed_at              timestamptz not null default now(),
  accepted_at            timestamptz,
  ready_at               timestamptz,
  picked_up_at           timestamptz,
  delivered_at           timestamptz,
  cancelled_at           timestamptz,
  cancelled_by           uuid references public.profiles (id) on delete set null,
  cancellation_reason    text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint orders_discount_ck check (discount_amount <= subtotal + delivery_fee + service_fee + tax_amount),
  constraint orders_cancel_reason_ck check (status not in ('cancelled', 'rejected') or cancelled_at is not null)
);

create table if not exists public.order_items (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid not null references public.orders (id) on delete cascade,
  product_id    uuid references public.products (id) on delete set null,
  product_name  text not null,                                      -- نسخة ثابتة من اسم المنتج
  unit_price    numeric(10,2) not null check (unit_price >= 0),     -- نسخة ثابتة من السعر وقت الطلب
  quantity      integer not null check (quantity between 1 and 99),
  line_total    numeric(10,2) generated always as (unit_price * quantity) stored,
  notes         text check (char_length(notes) <= 300),
  created_at    timestamptz not null default now()
);

-- سجل تغيّر حالات الطلب (Audit Trail)
create table if not exists public.order_status_history (
  id           bigint generated always as identity primary key,
  order_id     uuid not null references public.orders (id) on delete cascade,
  from_status  public.order_status,
  to_status    public.order_status not null,
  changed_by   uuid references public.profiles (id) on delete set null,
  note         text,
  created_at   timestamptz not null default now()
);


-- =====================================================================
-- 8) التوصيل ورمز التسليم (Deliveries & Delivery_OTP)
-- =====================================================================
create table if not exists public.deliveries (
  id                     uuid primary key default gen_random_uuid(),
  order_id               uuid not null references public.orders (id) on delete cascade,
  driver_id              uuid not null references public.drivers (user_id) on delete restrict,
  status                 public.delivery_status not null default 'assigned',
  pickup_location        geography(Point, 4326) not null,
  dropoff_location       geography(Point, 4326) not null,
  distance_to_store_m    integer check (distance_to_store_m >= 0),  -- مسافة السائق للمتجر وقت الإسناد
  driver_earning         numeric(10,2) not null default 0 check (driver_earning >= 0),
  proof_photo_url        text,
  failure_reason         text,
  assigned_at            timestamptz not null default now(),
  accepted_at            timestamptz,
  arrived_at_store_at    timestamptz,
  picked_up_at           timestamptz,
  arrived_at_customer_at timestamptz,
  delivered_at           timestamptz,
  cancelled_at           timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
comment on table public.deliveries is 'شحنة التوصيل: ربط الطلب بالسائق وتتبع مراحلها';

-- رمز التسليم: يُخزَّن مشفّراً (bcrypt) ولا يمكن قراءته من الجدول.
-- العميل يحصل على الرمز من الدالة issue_delivery_otp ويمليه للسائق،
-- والسائق يدخله في التطبيق عبر verify_delivery_otp.
create table if not exists public.delivery_otps (
  id            uuid primary key default gen_random_uuid(),
  delivery_id   uuid not null references public.deliveries (id) on delete cascade,
  code_hash     text not null,
  attempts      smallint not null default 0 check (attempts >= 0),
  max_attempts  smallint not null default 5 check (max_attempts between 1 and 10),
  expires_at    timestamptz not null,
  verified_at   timestamptz,
  invalidated_at timestamptz,
  created_at    timestamptz not null default now(),
  constraint delivery_otps_expiry_ck check (expires_at > created_at)
);


-- =====================================================================
-- 9) تتبع موقع السائق اللحظي (Driver_Locations)
-- =====================================================================
create table if not exists public.driver_locations (
  id            bigint generated always as identity primary key,
  driver_id     uuid not null references public.drivers (user_id) on delete cascade,
  delivery_id   uuid references public.deliveries (id) on delete set null,
  latitude      double precision not null check (latitude between -90 and 90),
  longitude     double precision not null check (longitude between -180 and 180),
  heading       numeric(5,2) check (heading >= 0 and heading < 360),   -- اتجاه السائق بالدرجات
  speed_kmh     numeric(6,2) check (speed_kmh >= 0 and speed_kmh <= 300),
  accuracy_m    numeric(7,2) check (accuracy_m >= 0),
  -- نقطة جغرافية محسوبة تلقائياً من خط الطول والعرض
  location      geography(Point, 4326)
                  generated always as (st_setsrid(st_makepoint(longitude, latitude), 4326)::geography) stored,
  recorded_at   timestamptz not null default now()
);
comment on table public.driver_locations is 'سجل مواقع السائق اللحظية (يُنظَّف دورياً بالدالة purge_old_driver_locations)';


-- =====================================================================
-- 10) الفهارس (Indexes)
-- =====================================================================

-- فهارس جغرافية (Spatial GIST)
create index if not exists stores_location_gix            on public.stores using gist (location);
create index if not exists drivers_current_location_gix   on public.drivers using gist (current_location)
  where availability = 'online' and is_verified;            -- فهرس جزئي للسائقين المتاحين فقط
create index if not exists driver_locations_location_gix  on public.driver_locations using gist (location);
create index if not exists user_addresses_location_gix    on public.user_addresses using gist (location);
create index if not exists orders_delivery_location_gix   on public.orders using gist (delivery_location);

-- المستخدمون والجلسات
create index if not exists profiles_role_idx              on public.profiles (role);
create index if not exists user_sessions_user_idx         on public.user_sessions (user_id) where revoked_at is null;
create index if not exists fcm_tokens_user_active_idx     on public.fcm_tokens (user_id) where is_active;
create index if not exists user_addresses_user_idx        on public.user_addresses (user_id);
create unique index if not exists user_addresses_one_default_uk
  on public.user_addresses (user_id) where is_default;     -- عنوان افتراضي واحد لكل عميل

-- المتاجر والمنتجات
create index if not exists stores_owner_idx               on public.stores (owner_id);
create index if not exists stores_active_open_idx         on public.stores (status, is_open);
create index if not exists stores_name_trgm_idx           on public.stores using gin (name extensions.gin_trgm_ops);
create index if not exists categories_store_sort_idx      on public.categories (store_id, sort_order);
create index if not exists products_store_category_idx    on public.products (store_id, category_id, sort_order);
create index if not exists products_status_idx            on public.products (store_id) where status = 'active';
create index if not exists products_name_trgm_idx         on public.products using gin (name extensions.gin_trgm_ops);
create index if not exists products_category_idx          on public.products (category_id);

-- الطلبات
create index if not exists orders_client_created_idx      on public.orders (client_id, created_at desc);
create index if not exists orders_store_status_idx        on public.orders (store_id, status, created_at desc);
create index if not exists orders_active_status_idx       on public.orders (status)
  where status not in ('delivered', 'cancelled', 'rejected');
create index if not exists orders_address_idx             on public.orders (delivery_address_id);
create index if not exists orders_cancelled_by_idx        on public.orders (cancelled_by);
create index if not exists order_items_order_idx          on public.order_items (order_id);
create index if not exists order_items_product_idx        on public.order_items (product_id);
create index if not exists order_status_history_order_idx on public.order_status_history (order_id, created_at);
create index if not exists order_status_history_by_idx    on public.order_status_history (changed_by);

-- التوصيل والتتبع
create index if not exists deliveries_driver_status_idx   on public.deliveries (driver_id, status);
create index if not exists deliveries_order_idx           on public.deliveries (order_id);
-- شحنة نشطة واحدة فقط لكل طلب (يسمح بإعادة الإسناد بعد الإلغاء)
create unique index if not exists deliveries_one_active_per_order_uk
  on public.deliveries (order_id) where status not in ('cancelled', 'failed');
create index if not exists delivery_otps_delivery_idx     on public.delivery_otps (delivery_id, created_at desc);
-- رمز فعال واحد فقط لكل شحنة
create unique index if not exists delivery_otps_one_active_uk
  on public.delivery_otps (delivery_id) where verified_at is null and invalidated_at is null;
create index if not exists driver_locations_driver_time_idx on public.driver_locations (driver_id, recorded_at desc);
create index if not exists driver_locations_delivery_idx  on public.driver_locations (delivery_id, recorded_at desc);
create index if not exists driver_locations_time_brin     on public.driver_locations using brin (recorded_at);


-- =====================================================================
-- 11) دوال الصلاحيات المساعدة (تُستخدم داخل سياسات RLS)
--     security definer لتجنب التكرار اللانهائي في سياسات RLS
-- =====================================================================
create or replace function public.current_user_role()
returns public.user_role
language sql stable security definer
set search_path = public, pg_temp
as $$
  select p.role from public.profiles p where p.id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin' and p.status = 'active'
  );
$$;

create or replace function public.owns_store(p_store_id uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (select 1 from public.stores s where s.id = p_store_id and s.owner_id = auth.uid());
$$;

-- هل المستخدم الحالي طرف في الطلب؟ (العميل، صاحب المتجر، السائق المسند، الأدمن)
create or replace function public.can_view_order(p_order_id uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select public.is_admin()
      or exists (
           select 1 from public.orders o
           join public.stores s on s.id = o.store_id
           where o.id = p_order_id
             and (o.client_id = auth.uid() or s.owner_id = auth.uid())
         )
      or exists (
           select 1 from public.deliveries d
           where d.order_id = p_order_id and d.driver_id = auth.uid()
             and d.status not in ('cancelled', 'failed')
         );
$$;

-- هل يحق للمستخدم الحالي رؤية موقع هذا السائق؟ (عميل لديه شحنة نشطة معه)
create or replace function public.can_track_driver(p_driver_id uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.deliveries d
    join public.orders o on o.id = d.order_id
    join public.stores s on s.id = o.store_id
    where d.driver_id = p_driver_id
      and d.status in ('assigned', 'accepted', 'arrived_at_store', 'picked_up', 'on_the_way', 'arrived_at_customer')
      and (o.client_id = auth.uid() or s.owner_id = auth.uid())
  );
$$;


-- =====================================================================
-- 12) إنشاء الملف الشخصي تلقائياً عند التسجيل في Supabase Auth
--     الدور يُقرأ من raw_user_meta_data.role (ممنوع اختيار admin من التطبيق)
-- =====================================================================
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_role public.user_role;
  v_requested text := coalesce(new.raw_user_meta_data ->> 'role', 'client');
begin
  v_role := case when v_requested in ('client', 'driver', 'store_owner')
                 then v_requested::public.user_role
                 else 'client'::public.user_role end;

  insert into public.profiles (id, role, full_name, phone, email)
  values (
    new.id,
    v_role,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'مستخدم جديد'),
    nullif(coalesce(new.phone, new.raw_user_meta_data ->> 'phone'), ''),
    nullif(new.email, '')
  );

  if v_role = 'driver' then
    insert into public.drivers (user_id) values (new.id);
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();


-- =====================================================================
-- 13) حماية الحقول الحساسة من التعديل بواسطة غير الأدمن
-- =====================================================================

-- المستخدم لا يغيّر دوره أو حالة حسابه بنفسه
create or replace function public.guard_profile_columns()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  -- pg_trigger_depth() = 1 يعني تعديل مباشر من المستخدم (وليس من دالة داخلية موثوقة)
  if auth.uid() is not null and pg_trigger_depth() = 1 and not public.is_admin() then
    if new.role is distinct from old.role or new.status is distinct from old.status then
      raise exception 'غير مسموح بتعديل الدور أو حالة الحساب' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

-- السائق لا يوثّق نفسه ولا يعدّل تقييمه
create or replace function public.guard_driver_columns()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  -- pg_trigger_depth() = 1 يعني تعديل مباشر من المستخدم (وليس من دالة داخلية موثوقة)
  if auth.uid() is not null and pg_trigger_depth() = 1 and not public.is_admin() then
    if new.is_verified      is distinct from old.is_verified
       or new.rating           is distinct from old.rating
       or new.total_deliveries is distinct from old.total_deliveries
       or new.max_concurrent_deliveries is distinct from old.max_concurrent_deliveries then
      raise exception 'غير مسموح بتعديل بيانات التوثيق أو التقييم' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

-- صاحب المتجر لا يغيّر العمولة أو حالة الموافقة
create or replace function public.guard_store_columns()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  -- pg_trigger_depth() = 1 يعني تعديل مباشر من المستخدم (وليس من دالة داخلية موثوقة)
  if auth.uid() is not null and pg_trigger_depth() = 1 and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.status := 'pending_approval';
      new.commission_rate := 15.00;
      new.rating := 0;
      new.rating_count := 0;
    elsif new.commission_rate is distinct from old.commission_rate
       or new.status is distinct from old.status
       or new.owner_id is distinct from old.owner_id
       or new.rating is distinct from old.rating
       or new.rating_count is distinct from old.rating_count then
      raise exception 'غير مسموح بتعديل العمولة أو حالة المتجر أو التقييم' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;


-- =====================================================================
-- 14) آلة حالات الطلب (Order State Machine)
--     تمنع القفز بين الحالات بشكل غير منطقي وتسجل التوقيتات والتاريخ
-- =====================================================================
create or replace function public.validate_order_status_transition()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_allowed boolean;
begin
  if new.status = old.status then
    return new;
  end if;

  v_allowed := case old.status
    when 'pending'          then new.status in ('accepted', 'rejected', 'cancelled')
    when 'accepted'         then new.status in ('preparing', 'cancelled')
    when 'preparing'        then new.status in ('ready_for_pickup', 'cancelled')
    when 'ready_for_pickup' then new.status in ('picked_up', 'cancelled')
    when 'picked_up'        then new.status in ('on_the_way', 'delivered')
    when 'on_the_way'       then new.status in ('delivered')
    else false  -- delivered / rejected / cancelled حالات نهائية
  end;

  if not v_allowed then
    raise exception 'انتقال غير مسموح لحالة الطلب من % إلى %', old.status, new.status
      using errcode = 'P0001';
  end if;

  -- تسجيل التوقيتات
  case new.status
    when 'accepted'         then new.accepted_at  := coalesce(new.accepted_at, now());
    when 'ready_for_pickup' then new.ready_at     := coalesce(new.ready_at, now());
    when 'picked_up'        then new.picked_up_at := coalesce(new.picked_up_at, now());
    when 'delivered'        then
      new.delivered_at := coalesce(new.delivered_at, now());
      if new.payment_method = 'cash' then
        new.payment_status := 'paid';
      end if;
    when 'cancelled', 'rejected' then
      new.cancelled_at := coalesce(new.cancelled_at, now());
      new.cancelled_by := coalesce(new.cancelled_by, auth.uid());
    else null;
  end case;

  return new;
end;
$$;

-- بعد تغيير الحالة: تسجيل التاريخ + إلغاء الشحنة النشطة لو الطلب اتلغى
create or replace function public.after_order_status_change()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.order_status_history (order_id, from_status, to_status, changed_by)
    values (new.id, null, new.status, auth.uid());
    return new;
  end if;

  if new.status is distinct from old.status then
    insert into public.order_status_history (order_id, from_status, to_status, changed_by, note)
    values (new.id, old.status, new.status, auth.uid(),
            case when new.status in ('cancelled', 'rejected') then new.cancellation_reason end);

    if new.status in ('cancelled', 'rejected') then
      update public.deliveries
         set status = 'cancelled', cancelled_at = now()
       where order_id = new.id
         and status not in ('delivered', 'failed', 'cancelled');
    end if;
  end if;
  return new;
end;
$$;


-- =====================================================================
-- 15) منطق الشحنة: آلة الحالات + الربط بحالة الطلب + منع التسليم بدون OTP
-- =====================================================================
create or replace function public.validate_delivery_status_transition()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_allowed boolean;
begin
  if new.status = old.status then
    return new;
  end if;

  v_allowed := case old.status
    when 'assigned'            then new.status in ('accepted', 'cancelled')
    when 'accepted'            then new.status in ('arrived_at_store', 'cancelled')
    when 'arrived_at_store'    then new.status in ('picked_up', 'cancelled')
    when 'picked_up'           then new.status in ('on_the_way', 'arrived_at_customer', 'failed')
    when 'on_the_way'          then new.status in ('arrived_at_customer', 'delivered', 'failed')
    when 'arrived_at_customer' then new.status in ('delivered', 'failed')
    else false
  end;

  if not v_allowed then
    raise exception 'انتقال غير مسموح لحالة الشحنة من % إلى %', old.status, new.status
      using errcode = 'P0001';
  end if;

  -- السائق لا يستلم الطلب إلا بعد ما المتجر يعلنه جاهز
  if new.status = 'picked_up' and not exists (
       select 1 from public.orders o
       where o.id = new.order_id and o.status = 'ready_for_pickup'
     ) then
    raise exception 'الطلب لم يصبح جاهزاً للاستلام بعد' using errcode = 'P0001';
  end if;

  -- حماية التسليم: لا يمكن وضع الحالة delivered إلا برمز OTP تم التحقق منه
  if new.status = 'delivered' and not exists (
       select 1 from public.delivery_otps o
       where o.delivery_id = new.id and o.verified_at is not null
     ) then
    raise exception 'لا يمكن تأكيد التسليم بدون التحقق من رمز OTP' using errcode = '42501';
  end if;

  case new.status
    when 'accepted'            then new.accepted_at            := coalesce(new.accepted_at, now());
    when 'arrived_at_store'    then new.arrived_at_store_at    := coalesce(new.arrived_at_store_at, now());
    when 'picked_up'           then new.picked_up_at           := coalesce(new.picked_up_at, now());
    when 'arrived_at_customer' then new.arrived_at_customer_at := coalesce(new.arrived_at_customer_at, now());
    when 'delivered'           then new.delivered_at           := coalesce(new.delivered_at, now());
    when 'cancelled'           then new.cancelled_at           := coalesce(new.cancelled_at, now());
    else null;
  end case;

  return new;
end;
$$;

-- مزامنة حالة الطلب وحالة السائق مع الشحنة
create or replace function public.sync_order_from_delivery()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_order_status public.order_status;
  v_active_count integer;
begin
  if new.status = old.status then
    return new;
  end if;

  select status into v_order_status from public.orders where id = new.order_id for update;

  if new.status = 'picked_up' and v_order_status = 'ready_for_pickup' then
    update public.orders set status = 'picked_up' where id = new.order_id;
  elsif new.status in ('on_the_way', 'arrived_at_customer') and v_order_status = 'picked_up' then
    update public.orders set status = 'on_the_way' where id = new.order_id;
  elsif new.status = 'delivered' and v_order_status in ('picked_up', 'on_the_way') then
    update public.orders set status = 'delivered' where id = new.order_id;
    update public.drivers set total_deliveries = total_deliveries + 1 where user_id = new.driver_id;
  end if;

  -- تحديث توفر السائق حسب عدد الشحنات النشطة
  select count(*) into v_active_count
  from public.deliveries
  where driver_id = new.driver_id
    and status in ('assigned', 'accepted', 'arrived_at_store', 'picked_up', 'on_the_way', 'arrived_at_customer');

  update public.drivers d
     set availability = case
           when v_active_count >= d.max_concurrent_deliveries then 'busy'::public.driver_availability
           when d.availability = 'busy' then 'online'::public.driver_availability
           else d.availability end
   where d.user_id = new.driver_id;

  return new;
end;
$$;


-- =====================================================================
-- 16) تحديث آخر موقع للسائق عند كل نقطة تتبع جديدة
-- =====================================================================
create or replace function public.update_driver_current_location()
returns trigger
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
begin
  update public.drivers
     set current_location = new.location,
         current_heading  = new.heading,
         last_location_at = new.recorded_at
   where user_id = new.driver_id
     and (last_location_at is null or last_location_at <= new.recorded_at);
  return new;
end;
$$;


-- =====================================================================
-- 17) ربط الـ Triggers
-- =====================================================================
drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_profiles_guard on public.profiles;
create trigger trg_profiles_guard before update on public.profiles
  for each row execute function public.guard_profile_columns();

drop trigger if exists trg_fcm_tokens_updated_at on public.fcm_tokens;
create trigger trg_fcm_tokens_updated_at before update on public.fcm_tokens
  for each row execute function public.set_updated_at();

drop trigger if exists trg_user_addresses_updated_at on public.user_addresses;
create trigger trg_user_addresses_updated_at before update on public.user_addresses
  for each row execute function public.set_updated_at();

drop trigger if exists trg_drivers_updated_at on public.drivers;
create trigger trg_drivers_updated_at before update on public.drivers
  for each row execute function public.set_updated_at();

drop trigger if exists trg_drivers_guard on public.drivers;
create trigger trg_drivers_guard before update on public.drivers
  for each row execute function public.guard_driver_columns();

drop trigger if exists trg_stores_updated_at on public.stores;
create trigger trg_stores_updated_at before update on public.stores
  for each row execute function public.set_updated_at();

drop trigger if exists trg_stores_guard on public.stores;
create trigger trg_stores_guard before insert or update on public.stores
  for each row execute function public.guard_store_columns();

drop trigger if exists trg_categories_updated_at on public.categories;
create trigger trg_categories_updated_at before update on public.categories
  for each row execute function public.set_updated_at();

drop trigger if exists trg_products_updated_at on public.products;
create trigger trg_products_updated_at before update on public.products
  for each row execute function public.set_updated_at();

drop trigger if exists trg_orders_updated_at on public.orders;
create trigger trg_orders_updated_at before update on public.orders
  for each row execute function public.set_updated_at();

drop trigger if exists trg_orders_validate_status on public.orders;
create trigger trg_orders_validate_status before update of status on public.orders
  for each row execute function public.validate_order_status_transition();

drop trigger if exists trg_orders_after_status on public.orders;
create trigger trg_orders_after_status after insert or update of status on public.orders
  for each row execute function public.after_order_status_change();

drop trigger if exists trg_deliveries_updated_at on public.deliveries;
create trigger trg_deliveries_updated_at before update on public.deliveries
  for each row execute function public.set_updated_at();

drop trigger if exists trg_deliveries_validate_status on public.deliveries;
create trigger trg_deliveries_validate_status before update of status on public.deliveries
  for each row execute function public.validate_delivery_status_transition();

drop trigger if exists trg_deliveries_sync_order on public.deliveries;
create trigger trg_deliveries_sync_order after update of status on public.deliveries
  for each row execute function public.sync_order_from_delivery();

drop trigger if exists trg_driver_locations_current on public.driver_locations;
create trigger trg_driver_locations_current after insert on public.driver_locations
  for each row execute function public.update_driver_current_location();


-- =====================================================================
-- 18) خوارزمية أقرب السائقين المتاحين (Nearest Available Drivers)
--
--  الفكرة:
--   1. نجيب نقطة المتجر.
--   2. نفلتر السائقين: online + موثّق + حسابه active + آخر موقع حديث
--      (أحدث من p_max_location_age) + داخل نصف القطر (ST_DWithin يستخدم فهرس GIST).
--   3. نرتب بـ KNN (<->) اللي بيستخدم الفهرس الجغرافي مباشرة.
--   4. نستبعد السائق اللي وصل للحد الأقصى من الشحنات النشطة.
--   5. نرجع المسافة الفعلية بالمتر والوقت التقريبي للوصول حسب نوع المركبة.
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

  -- مسموح فقط للأدمن أو صاحب المتجر أو الخدمات الخلفية (service_role)
  if auth.uid() is not null and not (public.is_admin() or public.owns_store(p_store_id)) then
    raise exception 'غير مصرح' using errcode = '42501';
  end if;

  select s.location into v_store_location from public.stores s where s.id = p_store_id;
  if v_store_location is null then
    raise exception 'المتجر غير موجود: %', p_store_id;
  end if;

  return query
  with candidates as (
    select d.user_id,
           d.vehicle_type,
           d.rating,
           d.current_location,
           d.current_heading,
           d.last_location_at,
           d.max_concurrent_deliveries,
           st_distance(d.current_location, v_store_location) as dist_m
    from public.drivers d
    join public.profiles p on p.id = d.user_id and p.status = 'active'
    where d.availability = 'online'
      and d.is_verified
      and d.current_location is not null
      and d.last_location_at >= now() - p_max_location_age
      and st_dwithin(d.current_location, v_store_location, p_radius_km * 1000)
    order by d.current_location <-> v_store_location
    limit p_limit * 3     -- نجيب عدد أكبر احتياطياً قبل فلترة السائقين المشغولين
  ),
  with_load as (
    select c.*,
           (select count(*)::integer
              from public.deliveries dl
             where dl.driver_id = c.user_id
               and dl.status in ('assigned', 'accepted', 'arrived_at_store', 'picked_up', 'on_the_way', 'arrived_at_customer')
           ) as active_cnt
    from candidates c
  )
  select w.user_id,
         p.full_name,
         p.phone,
         w.vehicle_type,
         w.rating,
         round(w.dist_m)::integer,
         -- الوقت التقريبي = المسافة / متوسط السرعة حسب المركبة (كم/س)
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


-- =====================================================================
-- 19) إسناد الطلب تلقائياً لأقرب سائق (آمن ضد التزامن)
--     FOR UPDATE SKIP LOCKED يمنع إسناد نفس السائق لطلبين في نفس اللحظة
-- =====================================================================
create or replace function public.assign_nearest_driver(
  p_order_id  uuid,
  p_radius_km numeric default null
)
returns uuid  -- رقم الشحنة أو null لو مفيش سائق متاح
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

  if auth.uid() is not null and not (public.is_admin() or public.owns_store(v_order.store_id)) then
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
    -- محاولة حجز السائق؛ لو محجوز من عملية أخرى نتخطاه
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
        v_candidate.distance_meters, round(v_order.delivery_fee * 0.80, 2)  -- 80% من رسوم التوصيل للسائق
      )
      returning id into v_delivery_id;

      -- لو وصل السائق للحد الأقصى يتحول لـ busy
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


-- =====================================================================
-- 20) إنشاء الطلب من جهة السيرفر (يمنع التلاعب بالأسعار من التطبيق)
--     p_items مثال: '[{"product_id":"...","quantity":2,"notes":"بدون بصل"}]'
-- =====================================================================
create or replace function public.place_order(
  p_store_id        uuid,
  p_address_id      uuid,
  p_items           jsonb,
  p_payment_method  public.payment_method default 'cash',
  p_notes           text default null
)
returns uuid
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid          uuid := auth.uid();
  v_store        public.stores%rowtype;
  v_address      public.user_addresses%rowtype;
  v_settings     public.platform_settings%rowtype;
  v_distance_km  numeric;
  v_subtotal     numeric(10,2) := 0;
  v_delivery_fee numeric(10,2);
  v_order_id     uuid;
  v_item         jsonb;
  v_product      public.products%rowtype;
  v_qty          integer;
  v_price        numeric(10,2);
  v_count        integer;
begin
  if v_uid is null then
    raise exception 'يجب تسجيل الدخول' using errcode = '42501';
  end if;
  if public.current_user_role() <> 'client' then
    raise exception 'فقط العملاء يمكنهم إنشاء طلبات' using errcode = '42501';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'سلة الطلب فارغة';
  end if;
  if jsonb_array_length(p_items) > 50 then
    raise exception 'عدد الأصناف أكبر من المسموح';
  end if;

  select * into v_store from public.stores where id = p_store_id;
  if not found or v_store.status <> 'active' or not v_store.is_open then
    raise exception 'المتجر غير متاح حالياً';
  end if;

  select * into v_address from public.user_addresses where id = p_address_id and user_id = v_uid;
  if not found then
    raise exception 'العنوان غير موجود';
  end if;

  v_distance_km := round((st_distance(v_store.location, v_address.location) / 1000.0)::numeric, 2);
  if v_distance_km > v_store.delivery_radius_km then
    raise exception 'العنوان خارج نطاق توصيل المتجر (% كم)', v_store.delivery_radius_km;
  end if;

  select * into v_settings from public.platform_settings where id;

  -- التحقق من المنتجات وحساب الإجمالي من الأسعار المخزنة
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item ->> 'quantity')::integer;
    if v_qty is null or v_qty < 1 or v_qty > 99 then
      raise exception 'كمية غير صحيحة';
    end if;

    select * into v_product
      from public.products
     where id = (v_item ->> 'product_id')::uuid
       and store_id = p_store_id
       and status = 'active';
    if not found then
      raise exception 'منتج غير متاح: %', v_item ->> 'product_id';
    end if;

    v_subtotal := v_subtotal + coalesce(v_product.discounted_price, v_product.price) * v_qty;
  end loop;

  if v_subtotal < v_store.min_order_amount then
    raise exception 'الحد الأدنى للطلب هو %', v_store.min_order_amount;
  end if;

  v_delivery_fee := round(v_store.delivery_fee_base + v_store.delivery_fee_per_km * v_distance_km, 2);

  insert into public.orders (
    client_id, store_id, delivery_address_id, delivery_address_text, delivery_location,
    subtotal, delivery_fee, service_fee, tax_amount, commission_rate, distance_km,
    payment_method, customer_notes, estimated_prep_minutes
  ) values (
    v_uid, p_store_id, v_address.id,
    concat_ws('، ', v_address.address_line, 'عمارة ' || v_address.building,
              'دور ' || v_address.floor, 'شقة ' || v_address.apartment, v_address.landmark),
    v_address.location,
    v_subtotal, v_delivery_fee, v_settings.service_fee,
    round(v_subtotal * v_settings.tax_rate / 100, 2),
    v_store.commission_rate, v_distance_km,
    p_payment_method, p_notes, v_store.avg_prep_time_minutes
  )
  returning id into v_order_id;

  insert into public.order_items (order_id, product_id, product_name, unit_price, quantity, notes)
  select v_order_id, pr.id, pr.name, coalesce(pr.discounted_price, pr.price),
         (i ->> 'quantity')::integer, nullif(i ->> 'notes', '')
  from jsonb_array_elements(p_items) i
  join public.products pr on pr.id = (i ->> 'product_id')::uuid;

  get diagnostics v_count = row_count;
  if v_count <> jsonb_array_length(p_items) then
    raise exception 'خطأ في أصناف الطلب';
  end if;

  return v_order_id;
end;
$$;


-- =====================================================================
-- 21) رمز التسليم OTP
-- =====================================================================

-- يستدعيها العميل لعرض الرمز في التطبيق (كل استدعاء يلغي الرمز السابق)
create or replace function public.issue_delivery_otp(p_delivery_id uuid)
returns text
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_client_id uuid;
  v_status    public.delivery_status;
  v_settings  public.platform_settings%rowtype;
  v_code      text;
begin
  select o.client_id, d.status into v_client_id, v_status
    from public.deliveries d
    join public.orders o on o.id = d.order_id
   where d.id = p_delivery_id;

  if not found then
    raise exception 'الشحنة غير موجودة';
  end if;
  if auth.uid() is distinct from v_client_id then
    raise exception 'الرمز متاح لصاحب الطلب فقط' using errcode = '42501';
  end if;
  if v_status in ('delivered', 'failed', 'cancelled') then
    raise exception 'الشحنة منتهية';
  end if;

  -- منع توليد الرموز بشكل متكرر جداً (مرة كل 30 ثانية)
  if exists (select 1 from public.delivery_otps
             where delivery_id = p_delivery_id and created_at > now() - interval '30 seconds') then
    raise exception 'انتظر قليلاً قبل طلب رمز جديد';
  end if;

  select * into v_settings from public.platform_settings where id;

  update public.delivery_otps
     set invalidated_at = now()
   where delivery_id = p_delivery_id and verified_at is null and invalidated_at is null;

  -- رمز من 4 أرقام عشوائي بشكل آمن (gen_random_bytes)
  v_code := lpad(((('x' || encode(gen_random_bytes(4), 'hex'))::bit(32)::bigint % 10000))::text, 4, '0');

  insert into public.delivery_otps (delivery_id, code_hash, max_attempts, expires_at)
  values (p_delivery_id, crypt(v_code, gen_salt('bf', 8)), v_settings.otp_max_attempts,
          now() + make_interval(mins => v_settings.otp_ttl_minutes));

  return v_code;
end;
$$;

-- يستدعيها السائق عند التسليم. ترجع JSON بالنتيجة بدلاً من رمي خطأ
-- حتى يتم حفظ عدد المحاولات الفاشلة (الخطأ يلغي التعديلات).
create or replace function public.verify_delivery_otp(p_delivery_id uuid, p_code text)
returns jsonb
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_delivery public.deliveries%rowtype;
  v_otp      public.delivery_otps%rowtype;
begin
  select * into v_delivery from public.deliveries where id = p_delivery_id for update;
  if not found then
    return jsonb_build_object('success', false, 'error', 'delivery_not_found');
  end if;
  if auth.uid() is not null and auth.uid() <> v_delivery.driver_id then
    return jsonb_build_object('success', false, 'error', 'not_assigned_driver');
  end if;
  if v_delivery.status not in ('picked_up', 'on_the_way', 'arrived_at_customer') then
    return jsonb_build_object('success', false, 'error', 'invalid_delivery_status');
  end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then
    return jsonb_build_object('success', false, 'error', 'invalid_code_format');
  end if;

  select * into v_otp
    from public.delivery_otps
   where delivery_id = p_delivery_id and verified_at is null and invalidated_at is null
   for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'no_active_otp');
  end if;
  if v_otp.expires_at < now() then
    update public.delivery_otps set invalidated_at = now() where id = v_otp.id;
    return jsonb_build_object('success', false, 'error', 'otp_expired');
  end if;
  if v_otp.attempts >= v_otp.max_attempts then
    update public.delivery_otps set invalidated_at = now() where id = v_otp.id;
    return jsonb_build_object('success', false, 'error', 'too_many_attempts');
  end if;

  if v_otp.code_hash = crypt(p_code, v_otp.code_hash) then
    update public.delivery_otps set verified_at = now(), attempts = attempts + 1 where id = v_otp.id;
    -- الـ trigger هيحدث الطلب لـ delivered تلقائياً
    update public.deliveries set status = 'delivered' where id = p_delivery_id;
    return jsonb_build_object('success', true);
  end if;

  update public.delivery_otps
     set attempts = attempts + 1,
         invalidated_at = case when attempts + 1 >= max_attempts then now() end
   where id = v_otp.id;

  return jsonb_build_object(
    'success', false,
    'error', 'wrong_code',
    'remaining_attempts', greatest(v_otp.max_attempts - v_otp.attempts - 1, 0)
  );
end;
$$;


-- =====================================================================
-- 22) تسجيل موقع السائق (يستدعيها تطبيق السائق كل 3-5 ثواني)
-- =====================================================================
create or replace function public.report_driver_location(
  p_latitude    double precision,
  p_longitude   double precision,
  p_heading     numeric default null,
  p_speed_kmh   numeric default null,
  p_accuracy_m  numeric default null
)
returns void
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid         uuid := auth.uid();
  v_delivery_id uuid;
begin
  if v_uid is null or not exists (select 1 from public.drivers where user_id = v_uid) then
    raise exception 'هذه الخدمة للسائقين فقط' using errcode = '42501';
  end if;

  select id into v_delivery_id
    from public.deliveries
   where driver_id = v_uid
     and status in ('accepted', 'arrived_at_store', 'picked_up', 'on_the_way', 'arrived_at_customer')
   order by assigned_at desc
   limit 1;

  insert into public.driver_locations (driver_id, delivery_id, latitude, longitude, heading, speed_kmh, accuracy_m)
  values (v_uid, v_delivery_id, p_latitude, p_longitude,
          case when p_heading is null then null else mod(p_heading, 360) end,
          p_speed_kmh, p_accuracy_m);
end;
$$;

-- تنظيف سجل المواقع القديم (يُجدول عبر pg_cron يومياً)
create or replace function public.purge_old_driver_locations(p_keep interval default interval '7 days')
returns bigint
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_deleted bigint;
begin
  delete from public.driver_locations where recorded_at < now() - p_keep;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;


-- =====================================================================
-- 23) سياسات الأمان (Row Level Security)
-- =====================================================================
alter table public.profiles             enable row level security;
alter table public.user_sessions        enable row level security;
alter table public.fcm_tokens           enable row level security;
alter table public.user_addresses       enable row level security;
alter table public.drivers              enable row level security;
alter table public.stores               enable row level security;
alter table public.store_working_hours  enable row level security;
alter table public.categories           enable row level security;
alter table public.products             enable row level security;
alter table public.platform_settings    enable row level security;
alter table public.orders               enable row level security;
alter table public.order_items          enable row level security;
alter table public.order_status_history enable row level security;
alter table public.deliveries           enable row level security;
alter table public.delivery_otps        enable row level security;  -- بدون أي سياسة = لا وصول إلا عبر الدوال
alter table public.driver_locations     enable row level security;

-- profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- user_sessions / fcm_tokens / user_addresses: المستخدم يدير بياناته فقط
drop policy if exists user_sessions_own on public.user_sessions;
create policy user_sessions_own on public.user_sessions for all to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

drop policy if exists fcm_tokens_own on public.fcm_tokens;
create policy fcm_tokens_own on public.fcm_tokens for all to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

drop policy if exists user_addresses_own on public.user_addresses;
create policy user_addresses_own on public.user_addresses for all to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

-- drivers
drop policy if exists drivers_select on public.drivers;
create policy drivers_select on public.drivers for select to authenticated
  using (user_id = auth.uid() or public.is_admin() or public.can_track_driver(user_id));
drop policy if exists drivers_update on public.drivers;
create policy drivers_update on public.drivers for update to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

-- stores: الكل يرى المتاجر النشطة، وصاحب المتجر يدير متجره
drop policy if exists stores_select on public.stores;
create policy stores_select on public.stores for select to anon, authenticated
  using (status = 'active' or owner_id = auth.uid() or public.is_admin());
drop policy if exists stores_insert on public.stores;
create policy stores_insert on public.stores for insert to authenticated
  with check ((owner_id = auth.uid() and public.current_user_role() = 'store_owner') or public.is_admin());
drop policy if exists stores_update on public.stores;
create policy stores_update on public.stores for update to authenticated
  using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());
drop policy if exists stores_delete on public.stores;
create policy stores_delete on public.stores for delete to authenticated
  using (public.is_admin());

-- store_working_hours / categories / products
drop policy if exists store_hours_select on public.store_working_hours;
create policy store_hours_select on public.store_working_hours for select to anon, authenticated
  using (true);
drop policy if exists store_hours_manage on public.store_working_hours;
create policy store_hours_manage on public.store_working_hours for all to authenticated
  using (public.owns_store(store_id) or public.is_admin())
  with check (public.owns_store(store_id) or public.is_admin());

drop policy if exists categories_select on public.categories;
create policy categories_select on public.categories for select to anon, authenticated
  using (is_active or public.owns_store(store_id) or public.is_admin());
drop policy if exists categories_manage on public.categories;
create policy categories_manage on public.categories for all to authenticated
  using (public.owns_store(store_id) or public.is_admin())
  with check (public.owns_store(store_id) or public.is_admin());

drop policy if exists products_select on public.products;
create policy products_select on public.products for select to anon, authenticated
  using (status in ('active', 'out_of_stock') or public.owns_store(store_id) or public.is_admin());
drop policy if exists products_manage on public.products;
create policy products_manage on public.products for all to authenticated
  using (public.owns_store(store_id) or public.is_admin())
  with check (public.owns_store(store_id) or public.is_admin());

-- platform_settings: قراءة للجميع وتعديل للأدمن
drop policy if exists platform_settings_select on public.platform_settings;
create policy platform_settings_select on public.platform_settings for select to anon, authenticated
  using (true);
drop policy if exists platform_settings_update on public.platform_settings;
create policy platform_settings_update on public.platform_settings for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- orders: الإنشاء فقط عبر place_order، والتعديل لصاحب المتجر (قبول/تحضير) أو الأدمن
drop policy if exists orders_select on public.orders;
create policy orders_select on public.orders for select to authenticated
  using (public.can_view_order(id));
drop policy if exists orders_update on public.orders;
create policy orders_update on public.orders for update to authenticated
  using (public.owns_store(store_id) or public.is_admin())
  with check (public.owns_store(store_id) or public.is_admin());

drop policy if exists order_items_select on public.order_items;
create policy order_items_select on public.order_items for select to authenticated
  using (public.can_view_order(order_id));

drop policy if exists order_status_history_select on public.order_status_history;
create policy order_status_history_select on public.order_status_history for select to authenticated
  using (public.can_view_order(order_id));

-- deliveries
drop policy if exists deliveries_select on public.deliveries;
create policy deliveries_select on public.deliveries for select to authenticated
  using (driver_id = auth.uid() or public.can_view_order(order_id));
drop policy if exists deliveries_update_driver on public.deliveries;
create policy deliveries_update_driver on public.deliveries for update to authenticated
  using (driver_id = auth.uid() or public.is_admin())
  with check (driver_id = auth.uid() or public.is_admin());

-- driver_locations
drop policy if exists driver_locations_select on public.driver_locations;
create policy driver_locations_select on public.driver_locations for select to authenticated
  using (driver_id = auth.uid() or public.is_admin() or public.can_track_driver(driver_id));
drop policy if exists driver_locations_insert on public.driver_locations;
create policy driver_locations_insert on public.driver_locations for insert to authenticated
  with check (driver_id = auth.uid());


-- صلاحيات الجداول (Supabase بيمنحها افتراضياً، وبنكتبها هنا للتأكيد)
-- الـ RLS هي اللي بتحدد فعلياً مين يشوف/يعدل إيه
grant usage on schema public to anon, authenticated, service_role;
grant select on all tables in schema public to anon;
grant select, insert, update, delete on all tables in schema public to authenticated, service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;


-- =====================================================================
-- 24) صلاحيات تنفيذ الدوال (RPC)
--     نمنع anon من الدوال الحساسة ونسمح بها لـ authenticated فقط
-- =====================================================================
revoke execute on function public.find_nearest_available_drivers(uuid, numeric, integer, interval) from public, anon;
revoke execute on function public.assign_nearest_driver(uuid, numeric)                             from public, anon;
revoke execute on function public.place_order(uuid, uuid, jsonb, public.payment_method, text)      from public, anon;
revoke execute on function public.issue_delivery_otp(uuid)                                          from public, anon;
revoke execute on function public.verify_delivery_otp(uuid, text)                                   from public, anon;
revoke execute on function public.report_driver_location(double precision, double precision, numeric, numeric, numeric) from public, anon;
revoke execute on function public.purge_old_driver_locations(interval)                              from public, anon, authenticated;
revoke execute on function public.handle_new_auth_user()                                            from public, anon, authenticated;

grant execute on function public.find_nearest_available_drivers(uuid, numeric, integer, interval) to authenticated, service_role;
grant execute on function public.assign_nearest_driver(uuid, numeric)                             to authenticated, service_role;
grant execute on function public.place_order(uuid, uuid, jsonb, public.payment_method, text)      to authenticated;
grant execute on function public.issue_delivery_otp(uuid)                                          to authenticated;
grant execute on function public.verify_delivery_otp(uuid, text)                                   to authenticated, service_role;
grant execute on function public.report_driver_location(double precision, double precision, numeric, numeric, numeric) to authenticated;
grant execute on function public.purge_old_driver_locations(interval)                              to service_role;


-- =====================================================================
-- 25) التحديثات اللحظية (Supabase Realtime / WebSockets)
--     تطبيق Flutter والداشبورد يشتركوا في تغييرات هذه الجداول،
--     والـ RLS بيتطبق تلقائياً على الرسائل اللي توصل لكل مستخدم.
-- =====================================================================
do $$
declare
  t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['orders', 'deliveries', 'driver_locations', 'drivers'] loop
      if not exists (
        select 1 from pg_publication_tables
        where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
      ) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;

-- =====================================================================
-- نهاية الملف
-- =====================================================================
