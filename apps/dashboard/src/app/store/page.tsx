'use client';

import { useState } from 'react';
import { OrdersChart, SalesChart } from '@/components/charts';
import { useStore } from '@/components/store-context';
import { Card, ErrorBox, PageHeader, Select, Spinner, Stat, Table, Td } from '@/components/ui';
import { fmtMoney, fmtNum } from '@/lib/format';
import { must, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';
import type { DailyPoint } from '@/lib/types';

interface StoreStats {
  orders_total: number;
  orders_delivered: number;
  orders_cancelled: number;
  orders_active: number;
  gross_sales: number;
  commission: number;
  payout: number;
  avg_order_value: number;
  avg_prep_minutes: number;
  daily: DailyPoint[];
  top_products: { name: string; qty: number; revenue: number }[];
}

export default function StoreOverview() {
  const { store } = useStore();
  const [days, setDays] = useState(30);
  const { data, error, loading, reload } = useLiveQuery<StoreStats>(
    async () => {
      const from = new Date();
      from.setHours(0, 0, 0, 0);
      from.setDate(from.getDate() - (days - 1));
      return must(await supabase().rpc('store_dashboard_stats', { p_store_id: store!.id, p_from: from.toISOString(), p_to: new Date().toISOString() }));
    },
    [store?.id, days],
    store ? [{ table: 'orders', filter: `store_id=eq.${store.id}` }] : [],
  );

  return (
    <>
      <PageHeader
        title="الإحصائيات"
        action={
          <Select value={days} onChange={(e) => setDays(Number(e.target.value))} className="w-40">
            <option value={1}>اليوم</option>
            <option value={7}>آخر 7 أيام</option>
            <option value={30}>آخر 30 يوم</option>
            <option value={90}>آخر 90 يوم</option>
          </Select>
        }
      />
      {error && <ErrorBox message={error} onRetry={reload} />}
      {loading && !data && <Spinner />}
      {data && (
        <div className="space-y-6">
          <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
            <Stat label="المبيعات (المسلّمة)" value={fmtMoney(data.gross_sales)} />
            <Stat label="صافي مستحقاتك" value={fmtMoney(data.payout)} tone="good" hint={`بعد عمولة ${fmtMoney(data.commission)}`} />
            <Stat label="الطلبات" value={fmtNum(data.orders_total)} hint={`${data.orders_delivered} مسلّم • ${data.orders_cancelled} ملغي/مرفوض`} />
            <Stat label="طلبات جارية الآن" value={fmtNum(data.orders_active)} tone="warn" />
            <Stat label="متوسط قيمة الطلب" value={fmtMoney(data.avg_order_value)} />
            <Stat label="متوسط وقت التحضير" value={`${data.avg_prep_minutes} دقيقة`} />
          </div>
          <div className="grid gap-6 xl:grid-cols-2">
            <Card title="المبيعات اليومية">
              <SalesChart data={data.daily} valueKey="sales" label="المبيعات" />
            </Card>
            <Card title="عدد الطلبات اليومي">
              <OrdersChart data={data.daily} />
            </Card>
          </div>
          <Card title="الأكثر مبيعاً">
            <Table head={['المنتج', 'الكمية', 'الإيراد']}>
              {data.top_products.map((p) => (
                <tr key={p.name}>
                  <Td className="font-semibold">{p.name}</Td>
                  <Td>{fmtNum(p.qty)}</Td>
                  <Td>{fmtMoney(p.revenue)}</Td>
                </tr>
              ))}
            </Table>
          </Card>
        </div>
      )}
    </>
  );
}
