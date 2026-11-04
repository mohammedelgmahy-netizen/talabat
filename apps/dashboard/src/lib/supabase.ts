'use client';

import { createClient, type SupabaseClient } from '@supabase/supabase-js';

/** الـ schema اللي فيها جداول التوصيل (لازم تكون مضافة في Exposed schemas) */
export const DB_SCHEMA = process.env.NEXT_PUBLIC_SUPABASE_SCHEMA || 'delivery';
/** علامة مستخدمي البرنامج ده لأن مشروع Supabase ممكن يكون مشترك مع برامج تانية */
export const APP_TAG = 'talabat';
export const MEDIA_BUCKET = 'talabat-media';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let client: SupabaseClient<any, any, any> | null = null;

/**
 * عميل Supabase للمتصفح. كل الصلاحيات بتتحدد بالـ RLS في قاعدة البيانات،
 * فاللوحة بتستخدم المفتاح العام فقط (ممنوع service_role هنا).
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function supabase(): SupabaseClient<any, any, any> {
  if (!client) {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.NEXT_PUBLIC_SUPABASE_KEY;
    if (!url || !key) {
      throw new Error('ضع NEXT_PUBLIC_SUPABASE_URL و NEXT_PUBLIC_SUPABASE_KEY في ملف .env.local');
    }
    client = createClient(url, key, { db: { schema: DB_SCHEMA }, auth: { persistSession: true, autoRefreshToken: true } });
  }
  return client;
}

/** رسالة خطأ عربية مفهومة من أخطاء PostgREST / Auth */
export function errorMessage(e: unknown): string {
  const msg = (e as { message?: string })?.message ?? String(e);
  if (/[؀-ۿ]/.test(msg)) return msg;
  if (/invalid login/i.test(msg)) return 'البريد أو كلمة المرور غير صحيحة';
  if (/duplicate key/i.test(msg)) return 'القيمة مستخدمة من قبل';
  if (/violates check constraint/i.test(msg)) return 'قيمة غير صحيحة في أحد الحقول';
  if (/failed to fetch/i.test(msg)) return 'تعذر الاتصال بالخادم';
  return msg;
}
