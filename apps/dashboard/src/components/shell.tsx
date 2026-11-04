'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, type ReactNode } from 'react';
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
// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function RoleShell({ role, nav, children, header }: { role: UserRole; nav: NavItem[]; children: ReactNode; header?: ReactNode }) {
  const { loading, session, profile, configError, signOut } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

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

  const current =
    nav.find((item) => pathname === item.href || pathname === item.href + '/') ??
    [...nav].sort((a, b) => b.href.length - a.href.length).find((item) => pathname.startsWith(item.href)) ??
    nav[0];
  const homeHref = nav[0].href;
  const atHome = current.href === homeHref;

  return (
    <div className="grid min-h-dvh grid-cols-[84px_minmax(0,1fr)] lg:grid-cols-[250px_minmax(0,1fr)]">
      {/* القائمة الجانبية: ظاهرة دايماً. على الموبايل أيقونة واسم صغير تحتها، وعلى الكمبيوتر بالعرض الكامل */}
      <aside className="sticky top-0 flex h-dvh flex-col overflow-y-auto border-e border-gray-200 bg-gray-50 px-1.5 py-2.5 lg:px-3.5 lg:py-4">
        <div className="mb-2.5 flex items-center justify-center gap-3 border-b border-gray-200 pb-2.5 lg:justify-start lg:px-2 lg:pb-4">
          <img src={`${process.env.NEXT_PUBLIC_BASE_PATH || ''}/icon-192.png`} alt="" className="size-10 shrink-0 rounded-xl lg:size-11" />
          <div className="hidden min-w-0 lg:block">
            <div className="text-lg font-extrabold leading-tight text-gray-900">طلبات</div>
            <div className="text-xs font-semibold text-gray-500">لوحة {roleLabel[role]}</div>
          </div>
        </div>
        <nav className="flex flex-col gap-1">
          {nav.map((item) => {
            const active = item.href === current.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                aria-current={active ? 'page' : undefined}
                className={cn(
                  'relative flex flex-col items-center gap-1 rounded-xl px-0.5 py-2 text-center text-[11px] font-bold leading-tight',
                  'lg:flex-row lg:gap-3 lg:px-3 lg:py-2.5 lg:text-start lg:text-[15px]',
                  active ? 'bg-orange-100 text-orange-700' : 'text-gray-700 hover:bg-white hover:text-gray-900',
                )}
              >
                {active && <span className="absolute inset-y-2 -start-1.5 w-1 rounded-e bg-orange-600 lg:-start-3.5" />}
                <span className="text-[22px] leading-none lg:text-xl">{item.icon}</span>
                <span>{item.label}</span>
              </Link>
            );
          })}
          <button
            onClick={() => signOut().then(() => router.replace('/login'))}
            className="flex flex-col items-center gap-1 rounded-xl px-0.5 py-2 text-[11px] font-bold leading-tight text-rose-600 hover:bg-white lg:flex-row lg:gap-3 lg:px-3 lg:py-2.5 lg:text-[15px]"
          >
            <span className="text-[22px] leading-none lg:text-xl">🚪</span>
            <span>تسجيل خروج</span>
          </button>
        </nav>
        <div className="mt-auto hidden border-t border-gray-200 px-2 pt-3 lg:block">
          <div className="truncate text-sm font-bold text-gray-900">{profile.full_name}</div>
          <div className="truncate text-xs font-semibold text-gray-500">{profile.email}</div>
        </div>
      </aside>

      <div className="min-w-0">
        {/* الشريط العلوي الملوّن زي سنام: رجوع + رئيسية + اسم الصفحة */}
        <header className="sticky top-0 z-[700] flex items-center gap-2.5 bg-orange-600 px-3 py-2.5 text-white shadow-md lg:gap-3 lg:px-7 lg:py-3">
          {!atHome && (
            <div className="flex gap-2">
              <button
                onClick={() => router.back()}
                aria-label="رجوع"
                className="grid size-9 place-items-center rounded-xl border border-white/20 bg-white/15 text-lg hover:bg-white/25 lg:size-10"
              >
                →
              </button>
              <Link
                href={homeHref}
                aria-label="الرئيسية"
                className="grid size-9 place-items-center rounded-xl border border-white/20 bg-white/15 text-lg hover:bg-white/25 lg:size-10"
              >
                ⌂
              </Link>
            </div>
          )}
          <div className="min-w-0 flex-1">
            <h1 className="truncate text-[17px] font-extrabold leading-tight lg:text-xl">{current.label}</h1>
            <div className="truncate text-xs font-semibold text-white/80">طلبات · لوحة {roleLabel[role]}</div>
          </div>
          <div className="hidden size-10 shrink-0 place-items-center rounded-full bg-white text-base font-extrabold text-orange-700 lg:grid">
            {(profile.full_name || '؟').trim()[0]}
          </div>
        </header>
        <main className="p-3 pb-16 lg:p-7">{children}</main>
      </div>
    </div>
  );
}
