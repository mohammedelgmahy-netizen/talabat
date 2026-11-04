'use client';

import { useState } from 'react';
import { OrderModal } from '@/components/order-modal';
import { useStore } from '@/components/store-context';
import { Button, Card, ErrorBox, OrderStatusBadge, PageHeader, Select, Spinner, Table, Td } from '@/components/ui';
import { fmtDateTime, fmtMoney, paymentLabel } from '@/lib/format';
import { must, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';
import type { OrderRow } from '@/lib/types';

const PAGE = 50;

export default function StoreHistoryPage() {
  const { store } = useStore();
  const [status, setStatus] = useState('all');
  const [page, setPage] = useState(0);
  const [openId, setOpenId] = useState<string | null>(null);

  const { data, error, loading } = useLiveQuery<OrderRow[]>(
    async () => {
      let q = supabase()
        .from('orders')
        .select('id, order_number, status, store_id, subtotal, delivery_fee, total_amount, commission_amount, store_payout, payment_method, payment_status, placed_at, customer_notes, estimated_prep_minutes')
        .eq('store_id', store!.id)
        .order('placed_at', { ascending: false })
        .range(page * PAGE, page * PAGE + PAGE - 1);
      q = status === 'all' ? q.in('status', ['delivered', 'cancelled', 'rejected']) : q.eq('status', status);
      return must(await q) as OrderRow[];
    },
    [store?.id, status, page],
  );

  return (
    <>
      <PageHeader title="سجل الطلبات" />
      <Card>
        <Select value={status} onChange={(e) => { setStatus(e.target.value); setPage(0); }} className="mb-4 w-48">
          <option value="all">كل المنتهية</option>
          <option value="delivered">المسلّمة</option>
          <option value="cancelled">الملغية</option>
          <option value="rejected">المرفوضة</option>
        </Select>
        {error && <ErrorBox message={error} />}
        {loading && !data ? (
          <Spinner />
        ) : (
          <Table head={['#', 'الحالة', 'المنتجات', 'العمولة', 'صافي لك', 'الدفع', 'التاريخ']}>
            {data?.map((o) => (
              <tr key={o.id} className="hover:bg-gray-50">
                <Td>
                  <button className="font-bold text-orange-700 hover:underline" onClick={() => setOpenId(o.id)}>
                    {o.order_number}
                  </button>
                </Td>
                <Td><OrderStatusBadge status={o.status} /></Td>
                <Td>{fmtMoney(o.subtotal)}</Td>
                <Td>{fmtMoney(o.commission_amount)}</Td>
                <Td className="font-semibold text-emerald-700">{o.status === 'delivered' ? fmtMoney(o.store_payout) : '—'}</Td>
                <Td>{paymentLabel[o.payment_method]}</Td>
                <Td className="text-gray-500">{fmtDateTime(o.placed_at)}</Td>
              </tr>
            ))}
          </Table>
        )}
        <div className="mt-4 flex justify-between">
          <Button variant="secondary" disabled={page === 0} onClick={() => setPage(page - 1)}>السابق</Button>
          <Button variant="secondary" disabled={(data?.length ?? 0) < PAGE} onClick={() => setPage(page + 1)}>التالي</Button>
        </div>
      </Card>
      <OrderModal orderId={openId} onClose={() => setOpenId(null)} showFinance />
    </>
  );
}
