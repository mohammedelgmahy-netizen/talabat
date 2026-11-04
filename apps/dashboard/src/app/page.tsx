'use client';

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { useAuth } from '@/components/auth-provider';
import { Button, ErrorBox, Spinner } from '@/components/ui';

/** توجيه كل مستخدم للوحة الخاصة بدوره */
export default function Home() {
  const { loading, session, profile, configError, signOut } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (loading || configError) return;
    if (!session) router.replace('/login');
    else if (profile?.role === 'admin') router.replace('/admin');
    else if (profile?.role === 'store_owner') router.replace('/store');
  }, [loading, session, profile, router, configError]);

  if (configError) return <div className="p-10"><ErrorBox message={configError} /></div>;
  if (loading || !session || !profile || profile.role === 'admin' || profile.role === 'store_owner') return <Spinner />;

  return (
    <div className="mx-auto max-w-md p-10 text-center">
      <div className="mb-4 text-5xl">📱</div>
      <h1 className="mb-2 text-xl font-bold">لوحة التحكم للإدارة وأصحاب المتاجر فقط</h1>
      <p className="mb-6 text-gray-500">حسابك ({profile.role === 'driver' ? 'سائق' : 'عميل'}) يعمل من تطبيق الموبايل.</p>
      <Button variant="secondary" onClick={() => signOut()}>
        تسجيل الخروج
      </Button>
    </div>
  );
}
