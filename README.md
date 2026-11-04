# برنامج طلبات — منصة توصيل (Supabase + Flutter + Next.js)

```
database/
  talabat_shared_project.sql  ⭐ الملف اللي بيتشغّل: كل البرنامج جوه schema اسمها delivery (آمن جوه مشروع فيه برامج تانية)
  supabase_full_setup.sql     نفس المحتوى لكن في public (لمشروع فاضي مخصص للبرنامج)
  delivery_schema.sql   الجداول، الـ Enums، الفهارس، الـ RLS، الدوال الأساسية (أقرب سائق، place_order، OTP)
  002_app_api.sql       طبقة الـ API للتطبيقات: إسناد آلي، حماية الأعمدة، دوال القراءة بالإحداثيات، الإحصائيات، Storage
apps/
  mobile/               تطبيق Flutter (عميل + سائق + صاحب متجر)
  dashboard/            لوحة Next.js (أدمن + صاحب متجر)
```

## خطوات التشغيل

1. أنشئ مشروع على supabase.com.
2. في SQL Editor شغّل `database/talabat_shared_project.sql`، ثم من Project Settings → Data API → Exposed schemas أضف `delivery`.
3. من Project Settings → API خذ **Project URL** و **Publishable key** (أو anon key).
4. اللوحة: انسخ `apps/dashboard/.env.example` إلى `.env.local` واملأ القيمتين، ثم `npm install && npm run dev`.
5. التطبيق: `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...`.
6. اعمل أول أدمن: سجّل حساب ثم `update public.profiles set role = 'admin' where email = '...';`
7. (اختياري) لإعادة محاولة إسناد الطلبات اللي ملهاش سائق كل دقيقة فعّل pg_cron وشغّل:
   `select cron.schedule('retry-assign', '* * * * *', 'select public.retry_unassigned_orders()');`

## دورة الطلب

العميل يطلب (`place_order` يحسب الأسعار في السيرفر) ← المتجر يقبل ← **إسناد آلي لأقرب سائق** ← السائق يقبل (لو رفض يتحول تلقائياً للسائق اللي بعده) ← المتجر يجهز ← السائق يستلم ويوصل ← العميل يُظهر رمز OTP ← السائق يدخله ← تم التسليم.
