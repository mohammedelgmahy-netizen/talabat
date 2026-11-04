'use client';

import { useState } from 'react';
import { OrderModal } from '@/components/order-modal';
import { Button, Card, ErrorBox, Input, OrderStatusBadge, PageHeader, Select, Spinner, Table, Td } from '@/components/ui';
import { ACTIVE_ORDER_STATUSES, deliveryStatusLabel, fmtDateTime, fmtMoney, orderStatusLabel, paymentLabel } from '@/lib/format';
import { must, useAction, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';
import type { OrderRow, OrderStatus } from '@/lib/types';

export default function AdminOrdersPage() {
  const [status, setStatus] = useState<string>('active');
  const [search, setSearch] = useState('');
  const [openId, setOpenId] = useState<string | null>(null);
  const action = useAction();

  const { data, error, loading } = useLiveQuery<OrderRow[]>(
    async () => {
      let q = supabase()
        .from('orders')
        .select('id, order_number, status, store_id, subtotal, delivery_fee, total_amount, commission_amount, store_payout, payment_method, payment_status, placed_at, customer_notes, estimated_prep_minutes, stores(name), deliveries(id, status)')
        .order('placed_at', { ascending: false })
        .limit(200);
      if (status === 'active') q = q.in('status', ACTIVE_ORDER_STATUSES);
      else if (status !== 'all') q = q.eq('status', status);
      if (/^\d+$/.test(search.trim())) q = q.eq('order_number', Number(search.trim()));
      return must(await q) as unknown as OrderRow[];
    },
    [status, search],
    [{ table: 'orders' }, { table: 'deliveries' }],
  );

  const cancel = (o: OrderRow) => {
    const reason = prompt(`سبب إلغاء الطلب #${o.order_number}؟`);
    if (!reason) return;
    action.run(async () => must(await supabase().from('orders').update({ status: 'cancelled', cancellation_reason: reason }).eq('id', o.id)));
  };

  const assign = (o: OrderRow) =>
    action.run(async () => {
      const id = must(await supabase().rpc('assign_nearest_driver', { p_order_id: o.id }));
      if (!id) throw new Error('لا يوجد سائق متاح قريب من المتجر حالياً');
    });

  return (
    <>
      <PageHeader title="الطلبات" subtitle="متابعة كل طلبات المنصة لحظياً" />
      <Card>
        <div className="mb-4 flex flex-wrap gap-3">
          <Select value={status} onChange={(e) => setStatus(e.target.value)} className="w-48">
            <option value="active">الجارية</option>
            <option value="all">الكل</option>
            {(Object.keys(orderStatusLabel) as OrderStatus[]).map((s) => (
              <option key={s} value={s}>
                {orderStatusLabel[s]}
              </option>
            ))}
          </Select>
          <Input placeholder="رقم الطلب" value={search} onChange={(e) => setSearch(e.target.value)} className="w-40" dir="ltr" />
        </div>
        {(error || action.error) && <ErrorBox message={(error || action.error)!} />}
        {loading && !data ? (
          <Spinner />
        ) : (
          <Table head={['#', 'المتجر', 'الحالة', 'السائق', 'الإجمالي', 'العمولة', 'الدفع', 'الوقت', '']}>
            {data?.map((o) => {
              const delivery = o.deliveries?.find((d) => !['cancelled', 'failed'].includes(d.status));
              const canAssign = ['accepted', 'preparing', 'ready_for_pickup'].includes(o.status) && !delivery;
              return (
                <tr key={o.id} className="hover:bg-gray-50">
                  <Td>
                    <button className="font-bold text-orange-700 hover:underline" onClick={() => setOpenId(o.id)}>
                      {o.order_number}
                    </button>
                  </Td>
                  <Td>{o.stores?.name}</Td>
                  <Td>
                    <OrderStatusBadge status={o.status} />
                  </Td>
                  <Td className="text-gray-600">{delivery ? deliveryStatusLabel[delivery.status] : '—'}</Td>
                  <Td>{fmtMoney(o.total_amount)}</Td>
                  <Td>{fmtMoney(o.commission_amount)}</Td>
                  <Td>{paymentLabel[o.payment_method]}</Td>
                  <Td className="text-gray-500">{fmtDateTime(o.placed_at)}</Td>
                  <Td>
                    <div className="flex gap-2">
                      {canAssign && (
                        <Button variant="secondary" className="px-2 py-1 text-xs" disabled={action.busy} onClick={() => assign(o)}>
                          إسناد سائق
                        </Button>
                      )}
                      {['pending', 'accepted', 'preparing', 'ready_for_pickup'].includes(o.status) && (
                        <Button variant="ghost" className="px-2 py-1 text-xs text-rose-600" disabled={action.busy} onClick={() => cancel(o)}>
                          إلغاء
                        </Button>
                      )}
                    </div>
                  </Td>
                </tr>
              );
            })}
          </Table>
        )}
      </Card>
      <OrderModal orderId={openId} onClose={() => setOpenId(null)} showFinance />
    </>
  );
}
