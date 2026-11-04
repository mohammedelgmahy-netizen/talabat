'use client';

import { RoleShell, type NavItem } from '@/components/shell';

const nav: NavItem[] = [
  { href: '/admin', label: 'نظرة عامة', icon: '📊' },
  { href: '/admin/live', label: 'الخريطة الحية', icon: '🗺️' },
  { href: '/admin/orders', label: 'الطلبات', icon: '🧾' },
  { href: '/admin/stores', label: 'المتاجر', icon: '🏪' },
  { href: '/admin/drivers', label: 'السائقون', icon: '🛵' },
  { href: '/admin/users', label: 'المستخدمون', icon: '👥' },
  { href: '/admin/settings', label: 'إعدادات المنصة', icon: '⚙️' },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <RoleShell role="admin" nav={nav} header={<span className="font-semibold text-gray-700">إدارة المنصة</span>}>
      {children}
    </RoleShell>
  );
}
