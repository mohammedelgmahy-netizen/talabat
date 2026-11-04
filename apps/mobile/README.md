# تطبيق طلبات (Flutter)

تطبيق واحد بثلاث واجهات حسب دور المستخدم بعد تسجيل الدخول:

| الدور | الشاشات |
|---|---|
| عميل | المتاجر القريبة والبحث، المنيو، السلة، العناوين على الخريطة، الدفع، تتبع الطلب لحظياً مع موقع السائق، رمز التسليم OTP، إلغاء الطلب قبل قبوله |
| سائق | متصل/غير متصل، استقبال الشحنات (قبول/رفض)، خطوات التوصيل، فتح الملاحة والاتصال، تأكيد التسليم بالـ OTP، الأرباح، إرسال الموقع تلقائياً |
| صاحب متجر | فتح/إغلاق المتجر، الطلبات اللحظية (قبول/رفض/تحضير/جاهز)، البحث عن سائق |

الأدمن يستخدم لوحة الويب (`apps/dashboard`).

## البنية (Clean Architecture)

```
lib/
  core/        الإعدادات، الأخطاء، الثيم، الراوتر، الخريطة، خدمات الموقع والجهاز والـ Realtime
  features/<feature>/
    domain/        الكيانات وعقود الـ Repository (بدون أي اعتماد على Supabase)
    data/          تنفيذ الـ Repository باستخدام Supabase (RPC + Realtime)
    presentation/  الشاشات و Riverpod providers
```

الحزم: `supabase_flutter`، `flutter_riverpod`، `go_router`، `flutter_map` (OpenStreetMap بدون مفتاح)، `geolocator`، `url_launcher`.

## التشغيل

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_KEY=sb_publishable_xxx
```

`SUPABASE_KEY` هو المفتاح العام (Publishable أو anon). ممنوع وضع service_role في التطبيق.

## الإشعارات (FCM) — اختياري

التطبيق بيسجل الجهاز في `user_sessions` و `fcm_tokens` عبر `register_device`. لتفعيل الإشعارات:
1. أضف Firebase للمشروع (`flutterfire configure`) و `firebase_messaging`.
2. اعمل كلاس ينفذ `PushTokenSource` باستخدام `FirebaseMessaging.instance.getToken()`.
3. استبدل `pushTokenSourceProvider` في `lib/core/providers.dart` بالكلاس الجديد.

## الاختبارات

```bash
flutter analyze
flutter test
```
