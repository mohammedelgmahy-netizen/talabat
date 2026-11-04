'use client';

import { useEffect, useState } from 'react';
import { Button, Card, ErrorBox, Field, Input, PageHeader, Select, Spinner } from '@/components/ui';
import { Map } from '@/components/map';
import { must, useAction, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';

interface Settings {
  service_fee: number;
  tax_rate: number;
  otp_ttl_minutes: number;
  otp_max_attempts: number;
  driver_search_radius_km: number;
  service_area_name: string;
  service_center_lat: number;
  service_center_lng: number;
  service_radius_km: number;
}

// مناطق جاهزة؛ وتقدر كمان تضغط على الخريطة تحدد أي مكان
const AREAS = [
  { name: 'برج العرب - الإسكندرية', lat: 30.895, lng: 29.59, km: 20 },
  { name: 'العجمي - الإسكندرية', lat: 31.09, lng: 29.76, km: 10 },
  { name: 'الإسكندرية كلها', lat: 31.2, lng: 29.92, km: 35 },
  { name: 'القاهرة والجيزة', lat: 30.0444, lng: 31.2357, km: 40 },
];

type NumKey = 'service_fee' | 'tax_rate' | 'driver_search_radius_km' | 'otp_ttl_minutes' | 'otp_max_attempts';
const fields: { key: NumKey; label: string; hint: string; step: number }[] = [
  { key: 'service_fee', label: 'رسوم الخدمة (ج.م)', hint: 'تضاف على كل طلب', step: 0.5 },
  { key: 'tax_rate', label: 'نسبة الضريبة %', hint: 'من قيمة المنتجات', step: 0.5 },
  { key: 'driver_search_radius_km', label: 'نطاق البحث عن سائق (كم)', hint: 'حول المتجر عند الإسناد الآلي', step: 0.5 },
  { key: 'otp_ttl_minutes', label: 'صلاحية رمز التسليم (دقيقة)', hint: 'من 5 إلى 1440', step: 1 },
  { key: 'otp_max_attempts', label: 'أقصى محاولات لرمز التسليم', hint: 'من 1 إلى 10', step: 1 },
];

export default function AdminSettingsPage() {
  const { data, error, loading } = useLiveQuery<Settings>(async () => must(await supabase().from('platform_settings').select('*').single()) as Settings, []);
  const [form, setForm] = useState<Settings | null>(null);
  const [saved, setSaved] = useState(false);
  const action = useAction();

  useEffect(() => {
    if (data) setForm(data);
  }, [data]);

  return (
    <>
      <PageHeader title="إعدادات المنصة" />
      {error && <ErrorBox message={error} />}
      {loading || !form ? (
        <Spinner />
      ) : (
        <>
        <Card className="mb-5 max-w-2xl">
          <div className="mb-1 text-lg font-bold">📍 منطقة الشغل</div>
          <p className="mb-4 text-sm text-gray-600">
            البرنامج هيشتغل في المنطقة دي بس: المحلات والعناوين والطلبات لازم تكون جوه الدايرة. اختار منطقة جاهزة، أو اضغط على الخريطة تحدد المركز.
          </p>
          <div className="mb-4 grid gap-4 sm:grid-cols-2">
            <Field label="المنطقة">
              <Select
                value={AREAS.some((a) => a.name === form.service_area_name) ? form.service_area_name : ''}
                onChange={(e) => {
                  const a = AREAS.find((x) => x.name === e.target.value);
                  if (a) setForm({ ...form, service_area_name: a.name, service_center_lat: a.lat, service_center_lng: a.lng, service_radius_km: a.km });
                }}
              >
                {AREAS.map((a) => (
                  <option key={a.name} value={a.name}>{a.name}</option>
                ))}
                <option value="">منطقة تانية (حددها على الخريطة)</option>
              </Select>
            </Field>
            <Field label="مساحة المنطقة (كم من المركز)">
              <Input type="number" step={1} min={1} dir="ltr" value={form.service_radius_km} onChange={(e) => setForm({ ...form, service_radius_km: Number(e.target.value) })} />
            </Field>
            {!AREAS.some((a) => a.name === form.service_area_name) && (
              <Field label="اسم المنطقة">
                <Input value={form.service_area_name} onChange={(e) => setForm({ ...form, service_area_name: e.target.value })} />
              </Field>
            )}
          </div>
          <Map
            center={[form.service_center_lat, form.service_center_lng]}
            zoom={10}
            height={320}
            follow
            circle={{ lat: form.service_center_lat, lng: form.service_center_lng, radiusKm: Number(form.service_radius_km) || 1 }}
            points={[{ id: 'c', lat: form.service_center_lat, lng: form.service_center_lng, color: '#ea580c', label: form.service_area_name, emoji: '📍' }]}
            onPick={(lat, lng) =>
              setForm({
                ...form,
                service_center_lat: Number(lat.toFixed(5)),
                service_center_lng: Number(lng.toFixed(5)),
                service_area_name: AREAS.some((a) => a.name === form.service_area_name) ? 'منطقة مخصصة' : form.service_area_name,
              })
            }
          />
        </Card>
        <Card className="max-w-2xl">
          <div className="grid gap-4 sm:grid-cols-2">
            {fields.map((f) => (
              <Field key={f.key} label={f.label} hint={f.hint}>
                <Input type="number" step={f.step} min={0} dir="ltr" value={form[f.key]} onChange={(e) => setForm({ ...form, [f.key]: Number(e.target.value) })} />
              </Field>
            ))}
          </div>
          {action.error && <div className="mt-4"><ErrorBox message={action.error} /></div>}
          {saved && <div className="mt-4 text-sm text-emerald-700">تم الحفظ ✓</div>}
          <Button
            className="mt-6"
            disabled={action.busy}
            onClick={async () => {
              setSaved(false);
              const ok = await action.run(async () => must(await supabase().from('platform_settings').update(form).eq('id', true)));
              setSaved(ok);
            }}
          >
            حفظ الإعدادات
          </Button>
        </Card>
        </>
      )}
    </>
  );
}
