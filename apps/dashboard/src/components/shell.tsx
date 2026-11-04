'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';
import { roleLabel } from '@/lib/format';
import type { UserRole } from '@/lib/types';
import { useAuth } from './auth-provider';
import { ErrorBox, Spinner, cn } from './ui';

export interface NavItem {
  href: string;
  label: string;
  icon: string;
}

/** يحمي الصفحات حسب الدور ويعرض القائمة الجانبية */
export function RoleShell({ role, nav, children, header }: { role: UserRole; nav: NavItem[]; children: ReactNode; header?: ReactNode }) {
  const { loading, session, profile, configError, signOut } = useAuth();
  const router = useRouter();
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  // أي انتقال لصفحة تانية يقفل القائمة على الموبايل
  useEffect(() => setOpen(false), [pathname]);

  useEffect(() => {
    if (loading || configError) return;
    if (!session) router.replace('/login');
    else if (profile && profile.role !== role) router.replace('/');
  }, [loading, session, profile, role, router, configError]);

  if (configError) return <div className="p-10"><ErrorBox message={configError} /></div>;
  if (loading || !session || !profile || profile.role !== role) return <Spinner />;
  if (profile.status !== 'active') {
    return (
      <div className="p-10">
        <ErrorBox message="حسابك موقوف. تواصل مع إدارة المنصة." />
      </div>
    );
  }

  return (
    <div className="min-h-screen lg:ps-64">
      <aside
        className={cn(
          'fixed inset-y-0 start-0 z-[900] flex h-dvh w-64 flex-col border-e border-gray-200 bg-white shadow-xl transition-transform duration-200 lg:shadow-none',
          open ? 'translate-x-0' : 'translate-x-full lg:translate-x-0',
        )}
      >
        <div className="flex h-16 shrink-0 items-center gap-2 border-b px-5">
          <span className="text-2xl">🛵</span>
          <div>
            <div className="font-bold">طلبات</div>
            <div className="text-xs text-gray-500">لوحة {roleLabel[role]}</div>
          </div>
        </div>
        <nav className="min-h-0 flex-1 space-y-1 overflow-y-auto p-3">
          {nav.map((item) => {
            const active = pathname === item.href || (item.href.split('/').length > 2 && pathname.startsWith(item.href));
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setOpen(false)}
                className={cn(
                  'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium',
                  active ? 'bg-orange-50 text-orange-700' : 'text-gray-700 hover:bg-gray-50',
                )}
              >
                <span className="text-lg">{item.icon}</span>
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="shrink-0 border-t p-4">
          <div className="mb-2 truncate text-sm font-semibold">{profile.full_name}</div>
          <div className="mb-3 truncate text-xs text-gray-500">{profile.email}</div>
          <button onClick={() => signOut().then(() => router.replace('/login'))} className="text-sm font-semibold text-rose-600">
            تسجيل الخروج
          </button>
        </div>
      </aside>
      {open && <div className="fixed inset-0 z-[800] bg-black/30 lg:hidden" onClick={() => setOpen(false)} />}
      <div className="min-w-0">
        <header className="sticky top-0 z-[700] flex h-16 items-center gap-3 border-b border-gray-200 bg-white/90 px-4 backdrop-blur lg:px-8">
          <button className="rounded-lg p-2 hover:bg-gray-100 lg:hidden" onClick={() => setOpen(true)} aria-label="القائمة">
            ☰
          </button>
          <div className="flex-1">{header}</div>
        </header>
        <main className="p-4 lg:p-8">{children}</main>
      </div>
    </div>
  );
}
