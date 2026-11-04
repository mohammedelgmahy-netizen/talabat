'use client';

import { useState } from 'react';
import { OrdersChart, SalesChart } from '@/components/charts';
import { Card, ErrorBox, PageHeader, Select, Spinner, Stat, Table, Td } from '@/components/ui';
import { fmtMoney, fmtNum } from '@/lib/format';
import { must, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';
import type { DailyPoint } from '@/lib/types';

interface AdminStats {
  orders_total: number;
  orders_delivered: number;
  orders_cancelled: number;
  orders_active: number;
  gmv: number;
  commission: number;
  service_fees: number;
  avg_delivery_minutes: number;
  clients: number;
  drivers_total: number;
  drivers_online: number;
  drivers_unverified: number;
  stores_active: number;
  stores_pending: number;
  daily: DailyPoint[];
  top_stores: { id: string; name: string; orders: number; sales: number }[];
}

export default function AdminOverview() {
  const [days, setDays] = useState(30);
  const { data, error, loading, reload } = useLiveQuery<AdminStats>(
    async () => {
      const from = new Date();
      from.setHours(0, 0, 0, 0);
      from.setDate(from.getDate() - (days - 1));
      return must(await supabase().rpc('admin_dashboard_stats', { p_from: from.toISOString(), p_to: new Date().toISOString() }));
    },
    [days],
    [{ table: 'orders' }],
  );

  return (
    <>
      <PageHeader
        title="نظرة عامة"
        subtitle="أرقام المنصة تتحدث لحظياً مع كل طلب"
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
            <Stat label="إجمالي المبيعات (GMV)" value={fmtMoney(data.gmv)} />
            <Stat label="عمولة المنصة" value={fmtMoney(data.commission)} tone="good" hint={`+ ${fmtMoney(data.service_fees)} رسوم خدمة`} />
            <Stat label="الطلبات" value={fmtNum(data.orders_total)} hint={`${fmtNum(data.orders_delivered)} مُسلّم • ${fmtNum(data.orders_cancelled)} ملغي/مرفوض`} />
            <Stat label="طلبات جارية الآن" value={fmtNum(data.orders_active)} tone="warn" />
            <Stat label="متوسط وقت التوصيل" value={`${data.avg_delivery_minutes} دقيقة`} />
            <Stat label="السائقون المتصلون" value={`${fmtNum(data.drivers_online)} / ${fmtNum(data.drivers_total)}`} hint={`${data.drivers_unverified} بانتظار التوثيق`} />
            <Stat label="المتاجر النشطة" value={fmtNum(data.stores_active)} hint={`${data.stores_pending} بانتظار الموافقة`} />
            <Stat label="العملاء" value={fmtNum(data.clients)} />
          </div>
          <div className="grid gap-6 xl:grid-cols-2">
            <Card title="المبيعات اليومية">
              <SalesChart data={data.daily} valueKey="gmv" label="المبيعات" />
            </Card>
            <Card title="عدد الطلبات اليومي">
              <OrdersChart data={data.daily} />
            </Card>
          </div>
          <Card title="أعلى المتاجر مبيعاً">
            <Table head={['المتجر', 'الطلبات المسلّمة', 'المبيعات']}>
              {data.top_stores.map((s) => (
                <tr key={s.id}>
                  <Td className="font-semibold">{s.name}</Td>
                  <Td>{fmtNum(s.orders)}</Td>
                  <Td>{fmtMoney(s.sales)}</Td>
                </tr>
              ))}
            </Table>
          </Card>
        </div>
      )}
    </>
  );
}
