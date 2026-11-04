'use client';

import { useEffect, useState } from 'react';
import { deliveryStatusLabel, fmtDateTime, fmtMoney, orderStatusLabel, paymentLabel } from '@/lib/format';
import { errorMessage, supabase } from '@/lib/supabase';
import type { OrderDetails } from '@/lib/types';
import { ErrorBox, Modal, OrderStatusBadge, Spinner } from './ui';

/** تفاصيل الطلب الكاملة من الدالة get_order_details */
export function OrderModal({ orderId, onClose, showFinance }: { orderId: string | null; onClose: () => void; showFinance?: boolean }) {
  const [order, setOrder] = useState<OrderDetails | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!orderId) return;
    setOrder(null);
    setError(null);
    supabase()
      .rpc('get_order_details', { p_order_id: orderId })
      .then(({ data, error }) => (error ? setError(errorMessage(error)) : setOrder(data as OrderDetails)));
  }, [orderId]);

  return (
    <Modal open={!!orderId} onClose={onClose} title={order ? `طلب #${order.order_number}` : 'تفاصيل الطلب'} wide>
      {error && <ErrorBox message={error} />}
      {!order && !error && <Spinner />}
      {order && (
        <div className="space-y-5 text-sm">
          <div className="flex flex-wrap items-center gap-3">
            <OrderStatusBadge status={order.status} />
            <span className="text-gray-500">{fmtDateTime(order.placed_at)}</span>
            <span className="text-gray-500">• {paymentLabel[order.payment_method]} ({order.payment_status})</span>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <Info title="العميل" lines={[order.client.full_name, order.client.phone ?? '']} />
            <Info title="المتجر" lines={[order.store.name, order.store.phone ?? '']} />
            <Info
              title="السائق"
              lines={order.delivery ? [order.delivery.driver_name, order.delivery.driver_phone ?? '', deliveryStatusLabel[order.delivery.status]] : ['لم يُسند بعد']}
            />
          </div>
          <Info title="عنوان التوصيل" lines={[order.delivery_address_text]} />
          {order.customer_notes && <Info title="ملاحظات العميل" lines={[order.customer_notes]} />}
          {order.cancellation_reason && <Info title="سبب الإلغاء/الرفض" lines={[order.cancellation_reason]} />}

          <table className="w-full">
            <tbody className="divide-y">
              {order.items.map((i, idx) => (
                <tr key={idx}>
                  <td className="py-2">
                    {i.quantity} × {i.product_name}
                    {i.notes && <div className="text-xs text-gray-500">{i.notes}</div>}
                  </td>
                  <td className="py-2 text-left">{fmtMoney(i.line_total)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="space-y-1 rounded-xl bg-gray-50 p-4">
            <Row l="المنتجات" v={order.subtotal} />
            <Row l="التوصيل" v={order.delivery_fee} />
            <Row l="رسوم الخدمة" v={order.service_fee} />
            {Number(order.tax_amount) > 0 && <Row l="الضريبة" v={order.tax_amount} />}
            {Number(order.discount_amount) > 0 && <Row l="الخصم" v={-order.discount_amount} />}
            <Row l="الإجمالي" v={order.total_amount} bold />
            {showFinance && (
              <>
                <hr className="my-2" />
                <Row l="عمولة المنصة" v={order.commission_amount} />
                <Row l="مستحق المتجر" v={order.store_payout} />
                {order.delivery && <Row l="ربح السائق" v={order.delivery.driver_earning} />}
              </>
            )}
          </div>
          <div>
            <div className="mb-2 font-semibold">سجل الحالات</div>
            <ol className="space-y-1 text-gray-600">
              {order.history.map((h, idx) => (
                <li key={idx}>
                  {fmtDateTime(h.at)} — {orderStatusLabel[h.to]}
                  {h.note ? ` (${h.note})` : ''}
                </li>
              ))}
            </ol>
          </div>
        </div>
      )}
    </Modal>
  );
}

function Info({ title, lines }: { title: string; lines: string[] }) {
  return (
    <div className="rounded-xl border p-3">
      <div className="mb-1 text-xs text-gray-500">{title}</div>
      {lines.filter(Boolean).map((l, i) => (
        <div key={i} className={i === 0 ? 'font-semibold' : 'text-gray-600'}>
          {l}
        </div>
      ))}
    </div>
  );
}

function Row({ l, v, bold }: { l: string; v: number; bold?: boolean }) {
  return (
    <div className={`flex justify-between ${bold ? 'font-bold' : ''}`}>
      <span>{l}</span>
      <span>{fmtMoney(v)}</span>
    </div>
  );
}
