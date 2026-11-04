'use client';

import { useEffect, useRef, useState } from 'react';
import { OrderModal } from '@/components/order-modal';
import { useStore } from '@/components/store-context';
import { Button, ErrorBox, PageHeader, Spinner } from '@/components/ui';
import { ACTIVE_ORDER_STATUSES, deliveryStatusLabel, fmtMoney, fmtTime, paymentLabel } from '@/lib/format';
import { must, useAction, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';
import type { OrderRow, OrderStatus } from '@/lib/types';

const columns: { title: string; statuses: OrderStatus[]; tone: string }[] = [
  { title: 'طلبات جديدة', statuses: ['pending'], tone: 'border-amber-400' },
  { title: 'قيد التحضير', statuses: ['accepted', 'preparing'], tone: 'border-blue-400' },
  { title: 'جاهز للاستلام', statuses: ['ready_for_pickup'], tone: 'border-indigo-400' },
  { title: 'مع السائق', statuses: ['picked_up', 'on_the_way'], tone: 'border-teal-400' },
];

const REJECT_REASONS = ['منتج غير متوفر', 'المتجر مشغول جداً', 'خارج أوقات العمل'];

/** لوحة استقبال الطلبات اللحظية (Kanban) مع تنبيه صوتي للطلبات الجديدة */
export default function StoreOrdersBoard() {
  const { store } = useStore();
  const [openId, setOpenId] = useState<string | null>(null);
  const action = useAction();
  const known = useRef<Set<string> | null>(null);

  const { data, error, loading } = useLiveQuery<OrderRow[]>(
    async () =>
      must(
        await supabase()
          .from('orders')
          .select('id, order_number, status, store_id, subtotal, delivery_fee, total_amount, commission_amount, store_payout, payment_method, payment_status, placed_at, customer_notes, estimated_prep_minutes, order_items(quantity, product_name, notes), deliveries(id, status)')
          .eq('store_id', store!.id)
          .in('status', ACTIVE_ORDER_STATUSES)
          .order('placed_at'),
      ) as unknown as OrderRow[],
    [store?.id],
    store ? [{ table: 'orders', filter: `store_id=eq.${store.id}` }, { table: 'deliveries' }] : [],
  );

  // تنبيه صوتي عند وصول طلب جديد
  useEffect(() => {
    if (!data) return;
    const pending = data.filter((o) => o.status === 'pending').map((o) => o.id);
    if (known.current && pending.some((id) => !known.current!.has(id))) beep();
    known.current = new Set(pending);
  }, [data]);

  const setStatus = (o: OrderRow, status: OrderStatus, reason?: string) =>
    action.run(async () =>
      must(await supabase().from('orders').update({ status, ...(reason ? { cancellation_reason: reason } : {}) }).eq('id', o.id)),
    );

  const assign = (o: OrderRow) =>
    action.run(async () => {
      const id = must(await supabase().rpc('assign_nearest_driver', { p_order_id: o.id }));
      if (!id) throw new Error('لا يوجد سائق متاح قريب حالياً، حاول بعد قليل');
    });

  return (
    <>
      <PageHeader title="الطلبات الحالية" subtitle="تتحدث لحظياً • يتم إسناد أقرب سائق تلقائياً عند قبول الطلب" />
      {(error || action.error) && <div className="mb-4"><ErrorBox message={(error || action.error)!} /></div>}
      {loading && !data ? (
        <Spinner />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 2xl:grid-cols-4">
          {columns.map((col) => {
            const list = (data ?? []).filter((o) => col.statuses.includes(o.status));
            return (
              <div key={col.title} className={`rounded-2xl border-t-4 bg-gray-100 p-3 ${col.tone}`}>
                <div className="mb-3 flex items-center justify-between px-1 font-bold">
                  {col.title}
                  <span className="rounded-full bg-white px-2 text-sm">{list.length}</span>
                </div>
                <div className="space-y-3">
                  {list.map((o) => {
                    const delivery = o.deliveries?.find((d) => !['cancelled', 'failed'].includes(d.status));
                    return (
                      <div key={o.id} className="rounded-xl bg-white p-3 shadow-sm">
                        <div className="flex items-center justify-between">
                          <button className="text-lg font-bold text-orange-700 hover:underline" onClick={() => setOpenId(o.id)}>
                            #{o.order_number}
                          </button>
                          <span className="text-xs text-gray-500">{fmtTime(o.placed_at)}</span>
                        </div>
                        <ul className="my-2 space-y-0.5 text-sm">
                          {o.order_items?.map((i, idx) => (
                            <li key={idx}>
                              <b>{i.quantity}×</b> {i.product_name}
                              {i.notes && <span className="text-xs text-gray-500"> ({i.notes})</span>}
                            </li>
                          ))}
                        </ul>
                        {o.customer_notes && <div className="mb-2 rounded bg-orange-50 p-2 text-xs text-orange-800">📝 {o.customer_notes}</div>}
                        <div className="flex justify-between text-sm">
                          <span className="font-semibold">{fmtMoney(o.subtotal)}</span>
                          <span className="text-gray-500">{paymentLabel[o.payment_method]}</span>
                        </div>
                        {o.status !== 'pending' && (
                          <div className="mt-1 text-xs text-gray-600">🛵 {delivery ? deliveryStatusLabel[delivery.status] : 'لم يُسند سائق بعد'}</div>
                        )}
                        <div className="mt-3 flex flex-wrap gap-2">
                          {o.status === 'pending' && (
                            <>
                              <Button className="flex-1" disabled={action.busy} onClick={() => setStatus(o, 'accepted')}>
                                قبول
                              </Button>
                              <select
                                className="rounded-lg border border-rose-300 px-2 text-sm text-rose-700"
                                value=""
                                disabled={action.busy}
                                onChange={(e) => e.target.value && setStatus(o, 'rejected', e.target.value)}
                              >
                                <option value="">رفض…</option>
                                {REJECT_REASONS.map((r) => (
                                  <option key={r} value={r}>
                                    {r}
                                  </option>
                                ))}
                              </select>
                            </>
                          )}
                          {o.status === 'accepted' && (
                            <Button className="flex-1" disabled={action.busy} onClick={() => setStatus(o, 'preparing')}>
                              بدء التحضير
                            </Button>
                          )}
                          {o.status === 'preparing' && (
                            <Button className="flex-1" disabled={action.busy} onClick={() => setStatus(o, 'ready_for_pickup')}>
                              جاهز للاستلام
                            </Button>
                          )}
                          {['accepted', 'preparing', 'ready_for_pickup'].includes(o.status) && !delivery && (
                            <Button variant="secondary" className="flex-1" disabled={action.busy} onClick={() => assign(o)}>
                              ابحث عن سائق
                            </Button>
                          )}
                        </div>
                      </div>
                    );
                  })}
                  {list.length === 0 && <div className="p-4 text-center text-sm text-gray-400">لا يوجد</div>}
                </div>
              </div>
            );
          })}
        </div>
      )}
      <OrderModal orderId={openId} onClose={() => setOpenId(null)} showFinance />
    </>
  );
}

function beep() {
  try {
    const ctx = new AudioContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.frequency.value = 880;
    gain.gain.setValueAtTime(0.2, ctx.currentTime);
    osc.start();
    osc.stop(ctx.currentTime + 0.4);
  } catch {
    /* المتصفح قد يمنع الصوت قبل أول تفاعل */
  }
}
