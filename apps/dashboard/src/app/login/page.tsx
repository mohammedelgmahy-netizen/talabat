'use client';

import { useRouter } from 'next/navigation';
import { useEffect, useState, type FormEvent } from 'react';
import { useAuth } from '@/components/auth-provider';
import { Button, ErrorBox, Field, Input } from '@/components/ui';
import { useAction } from '@/lib/hooks';
import { APP_TAG, loginId, supabase } from '@/lib/supabase';

export default function LoginPage() {
  const router = useRouter();
  const { session, configError } = useAuth();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [notice, setNotice] = useState<string | null>(null);
  const { busy, error, run } = useAction();

  useEffect(() => {
    if (session) router.replace('/');
  }, [session, router]);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setNotice(null);
    await run(async () => {
      if (mode === 'login') {
        const { error } = await supabase().auth.signInWithPassword({ email: loginId(email), password });
        if (error) throw error;
      } else {
        // التسجيل من اللوحة متاح لأصحاب المتاجر فقط؛ الأدمن يُعيَّن يدوياً من قاعدة البيانات
        const { data, error } = await supabase().auth.signUp({
          email: email.trim(),
          password,
          options: { data: { app: APP_TAG, full_name: fullName.trim(), phone: phone.trim() || undefined, role: 'store_owner' } },
        });
        if (error) throw error;
        if (!data.session) setNotice('تم إنشاء الحساب. أكّد بريدك الإلكتروني ثم سجّل الدخول.');
      }
    });
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-orange-700 to-orange-500 p-4">
      <form onSubmit={submit} className="w-full max-w-sm space-y-4 rounded-2xl bg-white p-7 shadow-2xl">
        <div className="text-center">
          <img src={`${process.env.NEXT_PUBLIC_BASE_PATH || ''}/icon-192.png`} alt="" className="mx-auto size-14 rounded-2xl" />
          <h1 className="mt-3 text-2xl font-extrabold">طلبات</h1>
          <p className="text-sm text-gray-500">{mode === 'login' ? 'تسجيل الدخول للوحة التحكم' : 'تسجيل متجر جديد'}</p>
        </div>
        {configError && <ErrorBox message={configError} />}
        {error && <ErrorBox message={error} />}
        {notice && <div className="rounded-xl bg-emerald-50 p-3 text-sm text-emerald-800">{notice}</div>}
        {mode === 'register' && (
          <>
            <Field label="الاسم">
              <Input required minLength={2} value={fullName} onChange={(e) => setFullName(e.target.value)} />
            </Field>
            <Field label="رقم الموبايل">
              <Input dir="ltr" pattern="\+?[0-9]{8,15}" value={phone} onChange={(e) => setPhone(e.target.value)} />
            </Field>
          </>
        )}
        <Field label={mode === 'login' ? 'الإيميل أو رقم الموبايل' : 'البريد الإلكتروني'}>
          <Input type={mode === 'login' ? 'text' : 'email'} dir="ltr" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </Field>
        <Field label="كلمة المرور">
          <Input type="password" dir="ltr" required minLength={6} value={password} onChange={(e) => setPassword(e.target.value)} />
        </Field>
        <Button type="submit" disabled={busy} className="w-full py-2.5">
          {busy ? '...' : mode === 'login' ? 'دخول' : 'إنشاء حساب متجر'}
        </Button>
        <button type="button" className="w-full text-sm text-orange-700" onClick={() => setMode(mode === 'login' ? 'register' : 'login')}>
          {mode === 'login' ? 'صاحب متجر جديد؟ سجّل هنا' : 'لديك حساب؟ سجّل الدخول'}
        </button>
      </form>
    </div>
  );
}
