'use client';

import { useState } from 'react';
import { Badge, Button, Card, ErrorBox, Field, Input, Modal, PageHeader, Select, Spinner, Table, Td } from '@/components/ui';
import { fmtDateTime, storeStatusLabel } from '@/lib/format';
import { must, useAction, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';
import type { Store } from '@/lib/types';

const statusColor: Record<string, string> = {
  pending_approval: 'bg-amber-100 text-amber-800',
  active: 'bg-emerald-100 text-emerald-800',
  suspended: 'bg-rose-100 text-rose-800',
  closed: 'bg-gray-200 text-gray-700',
};

export default function AdminStoresPage() {
  const [filter, setFilter] = useState('all');
  const [editing, setEditing] = useState<Store | null>(null);
  const action = useAction();

  const { data, error, loading, reload } = useLiveQuery<Store[]>(
    async () => {
      let q = supabase().from('stores').select('*').order('created_at', { ascending: false });
      if (filter !== 'all') q = q.eq('status', filter);
      return must(await q) as Store[];
    },
    [filter],
    [{ table: 'stores' }],
  );

  const setStatus = (s: Store, status: Store['status']) =>
    action.run(async () => {
      must(await supabase().from('stores').update({ status }).eq('id', s.id));
      await reload();
    });

  return (
    <>
      <PageHeader title="المتاجر" subtitle="الموافقة على المتاجر وتحديد نسبة العمولة" />
      <Card>
        <div className="mb-4">
          <Select value={filter} onChange={(e) => setFilter(e.target.value)} className="w-56">
            <option value="all">كل المتاجر</option>
            {Object.entries(storeStatusLabel).map(([k, v]) => (
              <option key={k} value={k}>
                {v}
              </option>
            ))}
          </Select>
        </div>
        {(error || action.error) && <ErrorBox message={(error || action.error)!} />}
        {loading && !data ? (
          <Spinner />
        ) : (
          <Table head={['المتجر', 'الحالة', 'مفتوح', 'العمولة', 'التقييم', 'التسجيل', '']}>
            {data?.map((s) => (
              <tr key={s.id} className="hover:bg-gray-50">
                <Td>
                  <div className="font-semibold">{s.name}</div>
                  <div className="text-xs text-gray-500">{s.address_line}</div>
                </Td>
                <Td>
                  <Badge className={statusColor[s.status]}>{storeStatusLabel[s.status]}</Badge>
                </Td>
                <Td>{s.is_open ? '🟢' : '⚪'}</Td>
                <Td>{Number(s.commission_rate)}%</Td>
                <Td>
                  {Number(s.rating).toFixed(1)} ({s.rating_count})
                </Td>
                <Td className="text-gray-500">{fmtDateTime(s.created_at)}</Td>
                <Td>
                  <div className="flex gap-2">
                    {s.status !== 'active' && (
                      <Button className="px-2 py-1 text-xs" disabled={action.busy} onClick={() => setStatus(s, 'active')}>
                        {s.status === 'pending_approval' ? 'موافقة' : 'تفعيل'}
                      </Button>
                    )}
                    {s.status === 'active' && (
                      <Button variant="danger" className="px-2 py-1 text-xs" disabled={action.busy} onClick={() => setStatus(s, 'suspended')}>
                        إيقاف
                      </Button>
                    )}
                    <Button variant="secondary" className="px-2 py-1 text-xs" onClick={() => setEditing(s)}>
                      العمولة
                    </Button>
                  </div>
                </Td>
              </tr>
            ))}
          </Table>
        )}
      </Card>
      {editing && <CommissionModal store={editing} onClose={() => setEditing(null)} onSaved={reload} />}
    </>
  );
}

function CommissionModal({ store, onClose, onSaved }: { store: Store; onClose: () => void; onSaved: () => void }) {
  const [rate, setRate] = useState(String(store.commission_rate));
  const { busy, error, run } = useAction();
  return (
    <Modal open onClose={onClose} title={`عمولة ${store.name}`}>
      <div className="space-y-4">
        {error && <ErrorBox message={error} />}
        <Field label="نسبة العمولة %" hint="تُطبّق على الطلبات الجديدة فقط (الطلبات القديمة محفوظة بنسبتها)">
          <Input type="number" min={0} max={100} step={0.5} value={rate} onChange={(e) => setRate(e.target.value)} dir="ltr" />
        </Field>
        <Button
          disabled={busy}
          onClick={async () => {
            const ok = await run(async () => must(await supabase().from('stores').update({ commission_rate: Number(rate) }).eq('id', store.id)));
            if (ok) {
              onSaved();
              onClose();
            }
          }}
        >
          حفظ
        </Button>
      </div>
    </Modal>
  );
}
