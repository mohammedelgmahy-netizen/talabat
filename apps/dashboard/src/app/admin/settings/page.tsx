'use client';

import { useEffect, useState } from 'react';
import { Button, Card, ErrorBox, Field, Input, PageHeader, Spinner } from '@/components/ui';
import { must, useAction, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';

interface Settings {
  service_fee: number;
  tax_rate: number;
  otp_ttl_minutes: number;
  otp_max_attempts: number;
  driver_search_radius_km: number;
}

const fields: { key: keyof Settings; label: string; hint: string; step: number }[] = [
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
      )}
    </>
  );
}
