'use client';

import { useEffect } from 'react';
import { Map, type MapPoint } from '@/components/map';
import { Card, ErrorBox, PageHeader, Spinner } from '@/components/ui';
import { orderStatusLabel } from '@/lib/format';
import { must, useLiveQuery } from '@/lib/hooks';
import { supabase } from '@/lib/supabase';
import type { OrderStatus } from '@/lib/types';

interface LiveMap {
  drivers: { id: string; name: string; availability: string; latitude: number; longitude: number; last_location_at: string }[];
  orders: { id: string; order_number: number; status: OrderStatus; store: string; latitude: number; longitude: number; store_latitude: number; store_longitude: number }[];
}

export default function LiveMapPage() {
  const { data, error, loading, reload } = useLiveQuery<LiveMap>(
    async () => must(await supabase().rpc('admin_live_map')),
    [],
    [{ table: 'orders' }, { table: 'drivers' }],
  );

  // احتياطي: تحديث كل 15 ثانية حتى لو مفيش أحداث
  useEffect(() => {
    const t = setInterval(reload, 15000);
    return () => clearInterval(t);
  }, [reload]);

  const points: MapPoint[] = [
    ...(data?.drivers ?? []).map((d) => ({
      id: `d-${d.id}`,
      lat: d.latitude,
      lng: d.longitude,
      color: '#0ea5e9',
      emoji: d.availability === 'busy' ? '🛵' : '🟢',
      label: `${d.name} (${d.availability === 'busy' ? 'مشغول' : d.availability === 'online' ? 'متاح' : 'استراحة'})`,
    })),
    ...(data?.orders ?? []).map((o) => ({
      id: `o-${o.id}`,
      lat: o.latitude,
      lng: o.longitude,
      color: '#ea580c',
      label: `#${o.order_number} • ${o.store} • ${orderStatusLabel[o.status]}`,
    })),
  ];
  const center: [number, number] = points.length ? [points[0].lat, points[0].lng] : [30.0444, 31.2357];

  return (
    <>
      <PageHeader title="الخريطة الحية" subtitle="🟢 سائق متاح • 🛵 سائق مشغول • ● عنوان طلب جاري" />
      {error && <ErrorBox message={error} onRetry={reload} />}
      {loading && !data ? (
        <Spinner />
      ) : (
        <div className="grid gap-6 xl:grid-cols-4">
          <div className="xl:col-span-3">
            <Map center={center} zoom={12} points={points} height={620} />
          </div>
          <Card title={`طلبات جارية (${data?.orders.length ?? 0})`}>
            <ul className="max-h-[560px] space-y-2 overflow-y-auto text-sm">
              {data?.orders.map((o) => (
                <li key={o.id} className="rounded-lg border p-2">
                  <div className="font-semibold">#{o.order_number} — {o.store}</div>
                  <div className="text-gray-500">{orderStatusLabel[o.status]}</div>
                </li>
              ))}
            </ul>
          </Card>
        </div>
      )}
    </>
  );
}
