'use client';

import { useState } from 'react';
import { Badge, Button, Card, ErrorBox, Input, PageHeader, Select, Spinner, Table, Td } from '@/components/ui';
import { fmtDateTime } from '@/lib/format';
import { must, useAction, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';

interface DriverRow {
  id: string;
  full_name: string;
  phone: string | null;
  email: string | null;
  status: string;
  created_at: string;
  driver_verified: boolean;
  driver_availability: string;
  vehicle_type: string;
  total_deliveries: number;
}

const availability: Record<string, [string, string]> = {
  online: ['متاح', 'bg-emerald-100 text-emerald-800'],
  busy: ['مشغول', 'bg-sky-100 text-sky-800'],
  on_break: ['استراحة', 'bg-amber-100 text-amber-800'],
  offline: ['غير متصل', 'bg-gray-100 text-gray-600'],
};

const vehicles: Record<string, string> = { bicycle: 'دراجة', motorcycle: 'موتوسيكل', car: 'سيارة', van: 'فان' };

export default function AdminDriversPage() {
  const [search, setSearch] = useState('');
  const [onlyPending, setOnlyPending] = useState(false);
  const action = useAction();

  const { data, error, loading, reload } = useLiveQuery<DriverRow[]>(
    async () => must(await supabase().rpc('admin_list_users', { p_role: 'driver', p_search: search || null, p_limit: 200, p_offset: 0 })) as DriverRow[],
    [search],
    [{ table: 'drivers' }],
  );

  const update = (id: string, patch: Record<string, unknown>) =>
    action.run(async () => {
      must(await supabase().from('drivers').update(patch).eq('user_id', id));
      await reload();
    });

  const rows = (data ?? []).filter((d) => !onlyPending || !d.driver_verified);

  return (
    <>
      <PageHeader title="السائقون" subtitle="توثيق السائقين ومتابعة حالتهم" />
      <Card>
        <div className="mb-4 flex flex-wrap items-center gap-3">
          <Input placeholder="بحث بالاسم أو الموبايل" value={search} onChange={(e) => setSearch(e.target.value)} className="w-64" />
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={onlyPending} onChange={(e) => setOnlyPending(e.target.checked)} />
            بانتظار التوثيق فقط
          </label>
        </div>
        {(error || action.error) && <ErrorBox message={(error || action.error)!} />}
        {loading && !data ? (
          <Spinner />
        ) : (
          <Table head={['السائق', 'الحالة', 'المركبة', 'التوصيلات', 'التوثيق', 'التسجيل', '']}>
            {rows.map((d) => (
              <tr key={d.id} className="hover:bg-gray-50">
                <Td>
                  <div className="font-semibold">{d.full_name}</div>
                  <div className="text-xs text-gray-500" dir="ltr">
                    {d.phone ?? d.email}
                  </div>
                </Td>
                <Td>
                  <Badge className={availability[d.driver_availability]?.[1]}>{availability[d.driver_availability]?.[0]}</Badge>
                </Td>
                <Td>
                  <Select
                    className="w-32 py-1"
                    value={d.vehicle_type}
                    onChange={(e) => update(d.id, { vehicle_type: e.target.value })}
                  >
                    {Object.entries(vehicles).map(([k, v]) => (
                      <option key={k} value={k}>
                        {v}
                      </option>
                    ))}
                  </Select>
                </Td>
                <Td>{d.total_deliveries}</Td>
                <Td>{d.driver_verified ? <Badge className="bg-emerald-100 text-emerald-800">موثّق</Badge> : <Badge className="bg-amber-100 text-amber-800">غير موثّق</Badge>}</Td>
                <Td className="text-gray-500">{fmtDateTime(d.created_at)}</Td>
                <Td>
                  <Button
                    variant={d.driver_verified ? 'secondary' : 'primary'}
                    className="px-2 py-1 text-xs"
                    disabled={action.busy}
                    onClick={() => update(d.id, { is_verified: !d.driver_verified })}
                  >
                    {d.driver_verified ? 'إلغاء التوثيق' : 'توثيق'}
                  </Button>
                </Td>
              </tr>
            ))}
          </Table>
        )}
      </Card>
    </>
  );
}
