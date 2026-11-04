'use client';

import { useEffect, useState } from 'react';
import { Map } from '@/components/map';
import { useStore } from '@/components/store-context';
import { Button, Card, ErrorBox, Field, Input, PageHeader, Spinner, Textarea } from '@/components/ui';
import { must, useAction } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';
import { uploadImage } from '@/lib/upload';

interface Form {
  name: string;
  slug: string;
  description: string;
  phone: string;
  logo_url: string;
  cover_url: string;
  address_line: string;
  latitude: number;
  longitude: number;
  delivery_radius_km: number;
  avg_prep_time_minutes: number;
  min_order_amount: number;
  delivery_fee_base: number;
  delivery_fee_per_km: number;
}

interface Hours {
  id?: string;
  day_of_week: number;
  open_time: string;
  close_time: string;
}

const DAYS = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

const empty: Form = {
  name: '',
  slug: '',
  description: '',
  phone: '',
  logo_url: '',
  cover_url: '',
  address_line: '',
  latitude: 30.895,
  longitude: 29.59,
  delivery_radius_km: 7,
  avg_prep_time_minutes: 20,
  min_order_amount: 0,
  delivery_fee_base: 10,
  delivery_fee_per_km: 2,
};

const slugify = (s: string) =>
  s.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || `store-${Math.random().toString(36).slice(2, 8)}`;

export default function StoreSettingsPage() {
  const { store, reload, select } = useStore();
  const [isNew, setIsNew] = useState(false);
  const [form, setForm] = useState<Form | null>(null);
  const [hours, setHours] = useState<Hours[]>([]);
  const [saved, setSaved] = useState(false);
  const action = useAction();

  useEffect(() => {
    setIsNew(window.location.hash === '#new' || !store);
  }, [store]);

  useEffect(() => {
    if (isNew || !store) {
      setForm(empty);
      setHours([]);
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition((p) => setForm((f) => (f ? { ...f, latitude: p.coords.latitude, longitude: p.coords.longitude } : f)));
      }
      return;
    }
    (async () => {
      const loc = must(await supabase().rpc('store_location', { p_store_id: store.id })) as { latitude: number; longitude: number }[];
      setForm({
        name: store.name,
        slug: store.slug,
        description: store.description ?? '',
        phone: store.phone ?? '',
        logo_url: store.logo_url ?? '',
        cover_url: store.cover_url ?? '',
        address_line: store.address_line,
        latitude: loc[0]?.latitude ?? empty.latitude,
        longitude: loc[0]?.longitude ?? empty.longitude,
        delivery_radius_km: Number(store.delivery_radius_km),
        avg_prep_time_minutes: store.avg_prep_time_minutes,
        min_order_amount: Number(store.min_order_amount),
        delivery_fee_base: Number(store.delivery_fee_base),
        delivery_fee_per_km: Number(store.delivery_fee_per_km),
      });
      const h = must(await supabase().from('store_working_hours').select('*').eq('store_id', store.id).order('day_of_week')) as Hours[];
      setHours(h.map((x) => ({ ...x, open_time: x.open_time.slice(0, 5), close_time: x.close_time.slice(0, 5) })));
    })().catch(() => setForm(empty));
  }, [store, isNew]);

  if (!form) return <Spinner />;
  const set = <K extends keyof Form>(k: K, v: Form[K]) => setForm({ ...form, [k]: v });

  const save = async () => {
    setSaved(false);
    const ok = await action.run(async () => {
      const id = must(
        await supabase().rpc('save_my_store', {
          p_id: isNew ? null : store!.id,
          p_name: form.name.trim(),
          p_slug: form.slug.trim() || slugify(form.name),
          p_description: form.description || null,
          p_phone: form.phone || null,
          p_logo_url: form.logo_url || null,
          p_cover_url: form.cover_url || null,
          p_address_line: form.address_line.trim(),
          p_latitude: form.latitude,
          p_longitude: form.longitude,
          p_delivery_radius_km: form.delivery_radius_km,
          p_avg_prep_time_minutes: form.avg_prep_time_minutes,
          p_min_order_amount: form.min_order_amount,
          p_delivery_fee_base: form.delivery_fee_base,
          p_delivery_fee_per_km: form.delivery_fee_per_km,
        }),
      ) as string;
      // مواعيد العمل: نستبدلها بالكامل
      must(await supabase().from('store_working_hours').delete().eq('store_id', id));
      const valid = hours.filter((h) => h.open_time && h.close_time && h.open_time !== h.close_time);
      if (valid.length) {
        must(await supabase().from('store_working_hours').insert(valid.map((h) => ({ store_id: id, day_of_week: h.day_of_week, open_time: h.open_time, close_time: h.close_time }))));
      }
      await reload();
      select(id);
      if (isNew) {
        history.replaceState(null, '', '/store/settings');
        setIsNew(false);
      }
    });
    setSaved(ok);
  };

  const upload = (key: 'logo_url' | 'cover_url', file: File) => {
    if (!store || isNew) {
      action.setError('احفظ المتجر أولاً ثم ارفع الصور');
      return;
    }
    action.run(async () => set(key, await uploadImage(store.id, file)));
  };

  return (
    <>
      <PageHeader
        title={isNew ? 'متجر جديد' : 'بيانات المتجر'}
        subtitle={isNew ? 'بعد الحفظ سيظهر متجرك للعملاء بمجرد موافقة الإدارة' : 'العمولة وحالة الموافقة تحددها الإدارة'}
      />
      <div className="grid gap-6 xl:grid-cols-2">
        <Card title="المعلومات الأساسية">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="اسم المتجر">
              <Input value={form.name} onChange={(e) => set('name', e.target.value)} />
            </Field>
            <Field label="الرابط المختصر (slug)" hint="حروف إنجليزية صغيرة وأرقام وشرطة">
              <Input dir="ltr" value={form.slug} placeholder={slugify(form.name)} onChange={(e) => set('slug', e.target.value)} />
            </Field>
            <Field label="رقم التليفون">
              <Input dir="ltr" value={form.phone} onChange={(e) => set('phone', e.target.value)} />
            </Field>
            <Field label="العنوان">
              <Input value={form.address_line} onChange={(e) => set('address_line', e.target.value)} />
            </Field>
            <div className="sm:col-span-2">
              <Field label="الوصف">
                <Textarea rows={2} value={form.description} onChange={(e) => set('description', e.target.value)} />
              </Field>
            </div>
            <Field label="الشعار (Logo)">
              <input type="file" accept="image/*" onChange={(e) => e.target.files?.[0] && upload('logo_url', e.target.files[0])} />
              {form.logo_url && (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={form.logo_url} alt="" className="mt-2 h-16 w-16 rounded-full object-cover" />
              )}
            </Field>
            <Field label="صورة الغلاف">
              <input type="file" accept="image/*" onChange={(e) => e.target.files?.[0] && upload('cover_url', e.target.files[0])} />
              {form.cover_url && (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={form.cover_url} alt="" className="mt-2 h-16 w-full rounded-lg object-cover" />
              )}
            </Field>
          </div>
        </Card>
        <Card title="التوصيل والتسعير">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="نطاق التوصيل (كم)">
              <Input type="number" min={0.5} max={50} step={0.5} dir="ltr" value={form.delivery_radius_km} onChange={(e) => set('delivery_radius_km', Number(e.target.value))} />
            </Field>
            <Field label="متوسط وقت التحضير (دقيقة)">
              <Input type="number" min={1} max={240} dir="ltr" value={form.avg_prep_time_minutes} onChange={(e) => set('avg_prep_time_minutes', Number(e.target.value))} />
            </Field>
            <Field label="الحد الأدنى للطلب (ج.م)">
              <Input type="number" min={0} dir="ltr" value={form.min_order_amount} onChange={(e) => set('min_order_amount', Number(e.target.value))} />
            </Field>
            <Field label="رسوم توصيل أساسية (ج.م)">
              <Input type="number" min={0} step={0.5} dir="ltr" value={form.delivery_fee_base} onChange={(e) => set('delivery_fee_base', Number(e.target.value))} />
            </Field>
            <Field label="رسوم لكل كيلومتر (ج.م)" hint="رسوم التوصيل = الأساسية + (المسافة × سعر الكيلو)">
              <Input type="number" min={0} step={0.5} dir="ltr" value={form.delivery_fee_per_km} onChange={(e) => set('delivery_fee_per_km', Number(e.target.value))} />
            </Field>
            {!isNew && store && (
              <Field label="عمولة المنصة">
                <div className="py-2 font-semibold">{Number(store.commission_rate)}%</div>
              </Field>
            )}
          </div>
        </Card>
        <Card title="موقع المتجر على الخريطة" className="xl:col-span-2">
          <p className="mb-3 text-sm text-gray-500">اضغط على الخريطة لتحديد الموقع بدقة. يستخدم لحساب المسافة ورسوم التوصيل والبحث عن أقرب سائق.</p>
          <Map
            center={[form.latitude, form.longitude]}
            zoom={15}
            height={360}
            follow
            onPick={(lat, lng) => setForm({ ...form, latitude: lat, longitude: lng })}
            points={[{ id: 'store', lat: form.latitude, lng: form.longitude, color: '#ea580c', emoji: '🏪', label: form.name || 'المتجر' }]}
          />
          <div className="mt-2 text-xs text-gray-500" dir="ltr">
            {form.latitude.toFixed(6)}, {form.longitude.toFixed(6)}
          </div>
        </Card>
        <Card title="مواعيد العمل" className="xl:col-span-2" action={<Button variant="secondary" className="px-2 py-1 text-xs" onClick={() => setHours([...hours, { day_of_week: 0, open_time: '10:00', close_time: '23:00' }])}>+ فترة</Button>}>
          {hours.length === 0 && <div className="text-sm text-gray-400">لم تُحدد مواعيد. يمكنك فتح وإغلاق المتجر يدوياً من الشريط العلوي.</div>}
          <div className="space-y-2">
            {hours.map((h, i) => (
              <div key={i} className="flex flex-wrap items-center gap-2">
                <select className="rounded-lg border px-2 py-1.5 text-sm" value={h.day_of_week} onChange={(e) => setHours(hours.map((x, j) => (j === i ? { ...x, day_of_week: Number(e.target.value) } : x)))}>
                  {DAYS.map((d, k) => (
                    <option key={k} value={k}>{d}</option>
                  ))}
                </select>
                <span>من</span>
                <input type="time" className="rounded-lg border px-2 py-1 text-sm" value={h.open_time} onChange={(e) => setHours(hours.map((x, j) => (j === i ? { ...x, open_time: e.target.value } : x)))} />
                <span>إلى</span>
                <input type="time" className="rounded-lg border px-2 py-1 text-sm" value={h.close_time} onChange={(e) => setHours(hours.map((x, j) => (j === i ? { ...x, close_time: e.target.value } : x)))} />
                <button className="text-sm text-rose-600" onClick={() => setHours(hours.filter((_, j) => j !== i))}>حذف</button>
              </div>
            ))}
          </div>
        </Card>
      </div>
      <div className="mt-6 flex items-center gap-4">
        <Button onClick={save} disabled={action.busy || !form.name.trim() || !form.address_line.trim()}>
          {action.busy ? '...' : isNew ? 'إنشاء المتجر' : 'حفظ التعديلات'}
        </Button>
        {saved && <span className="text-sm text-emerald-700">تم الحفظ ✓</span>}
        {action.error && <ErrorBox message={action.error} />}
      </div>
    </>
  );
}
