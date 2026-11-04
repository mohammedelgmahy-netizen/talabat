'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { RoleShell, type NavItem } from '@/components/shell';
import { StoreProvider, useStore } from '@/components/store-context';
import { Badge, Select, Spinner } from '@/components/ui';
import { must, useAction } from '@/lib/hooks';
import { storeStatusLabel } from '@/lib/format';
import { supabase } from '@/lib/supabase';

const nav: NavItem[] = [
  { href: '/store', label: 'الإحصائيات', icon: '📊' },
  { href: '/store/orders', label: 'الطلبات الحالية', icon: '🔔' },
  { href: '/store/history', label: 'سجل الطلبات', icon: '🧾' },
  { href: '/store/menu', label: 'المنيو والمنتجات', icon: '🍔' },
  { href: '/store/settings', label: 'بيانات المتجر', icon: '⚙️' },
];

export default function StoreLayout({ children }: { children: React.ReactNode }) {
  return (
    <RoleShell
      role="store_owner"
      nav={nav}
      header={<span className="font-semibold text-gray-700">لوحة المتجر</span>}
    >
      <StoreGate>{children}</StoreGate>
    </RoleShell>
  );
}

function StoreGate({ children }: { children: React.ReactNode }) {
  return (
    <StoreProvider>
      <StoreBar />
      <GateInner>{children}</GateInner>
    </StoreProvider>
  );
}

function GateInner({ children }: { children: React.ReactNode }) {
  const { store, loading } = useStore();
  const pathname = usePathname();
  if (loading) return <Spinner />;
  if (!store && pathname !== '/store/settings') {
    return (
      <div className="mx-auto max-w-md rounded-2xl border bg-white p-10 text-center">
        <div className="text-5xl">🏪</div>
        <h2 className="mt-3 text-xl font-bold">أضف متجرك</h2>
        <p className="mt-2 text-sm text-gray-500">سجّل بيانات متجرك وموقعه، وبعد موافقة الإدارة يظهر للعملاء.</p>
        <Link href="/store/settings" className="mt-6 inline-block rounded-lg bg-orange-600 px-5 py-2 font-semibold text-white">
          إضافة متجر
        </Link>
      </div>
    );
  }
  return <>{children}</>;
}

/** شريط المتجر: اختيار المتجر + فتح/إغلاق استقبال الطلبات */
function StoreBar() {
  const { stores, store, select, reload } = useStore();
  const { busy, error, run } = useAction();
  if (!store) return null;
  const toggle = () =>
    run(async () => {
      must(await supabase().from('stores').update({ is_open: !store.is_open }).eq('id', store.id));
      await reload();
    });
  return (
    <div className="mb-6 flex flex-wrap items-center gap-3 rounded-2xl border bg-white p-4">
      {stores.length > 1 ? (
        <Select value={store.id} onChange={(e) => select(e.target.value)} className="w-56">
          {stores.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </Select>
      ) : (
        <div className="text-lg font-bold">{store.name}</div>
      )}
      <Badge className={store.status === 'active' ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-800'}>{storeStatusLabel[store.status]}</Badge>
      <div className="flex-1" />
      {error && <span className="text-sm text-rose-600">{error}</span>}
      {store.status === 'active' && (
        <button
          onClick={toggle}
          disabled={busy}
          className={`rounded-full px-4 py-2 text-sm font-bold ${store.is_open ? 'bg-emerald-600 text-white' : 'bg-gray-200 text-gray-700'}`}
        >
          {store.is_open ? '🟢 مفتوح — يستقبل الطلبات' : '⚪ مغلق — اضغط للفتح'}
        </button>
      )}
      <Link href="/store/settings#new" className="text-sm text-orange-700">
        + متجر آخر
      </Link>
    </div>
  );
}
