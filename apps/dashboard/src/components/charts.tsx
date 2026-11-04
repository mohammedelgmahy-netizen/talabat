'use client';

import { Area, AreaChart, Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import type { DailyPoint } from '@/lib/types';

const dayLabel = (d: string) => new Date(d).toLocaleDateString('ar-EG', { day: 'numeric', month: 'short' });

export function SalesChart({ data, valueKey, label }: { data: DailyPoint[]; valueKey: 'sales' | 'gmv'; label: string }) {
  return (
    <div className="h-72" dir="ltr">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={data} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
          <defs>
            <linearGradient id="fill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#ea580c" stopOpacity={0.35} />
              <stop offset="100%" stopColor="#ea580c" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#eee" vertical={false} />
          <XAxis dataKey="day" tickFormatter={dayLabel} fontSize={12} />
          <YAxis fontSize={12} width={50} />
          <Tooltip labelFormatter={(d) => dayLabel(String(d))} formatter={(v) => [Number(v).toLocaleString('ar-EG'), label]} />
          <Area type="monotone" dataKey={valueKey} stroke="#ea580c" strokeWidth={2} fill="url(#fill)" />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

export function OrdersChart({ data }: { data: DailyPoint[] }) {
  return (
    <div className="h-72" dir="ltr">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart data={data} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#eee" vertical={false} />
          <XAxis dataKey="day" tickFormatter={dayLabel} fontSize={12} />
          <YAxis allowDecimals={false} fontSize={12} width={40} />
          <Tooltip labelFormatter={(d) => dayLabel(String(d))} formatter={(v) => [v, 'طلبات']} />
          <Bar dataKey="orders" fill="#0ea5e9" radius={[4, 4, 0, 0]} />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
