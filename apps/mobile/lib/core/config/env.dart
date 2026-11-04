/// إعدادات البيئة: تُمرَّر وقت التشغيل/البناء بدون كتابتها في الكود
///
/// flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///             --dart-define=SUPABASE_KEY=sb_publishable_...   (أو الـ anon key القديم eyJ...)
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://opfbfbragbmfxsgyslam.supabase.co');
  /// المفتاح العام (Publishable / anon). ممنوع تماماً وضع service_role key هنا
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: 'sb_publishable_uEc0xuXF4PvRNpKTD2Oqqw_ybzdP9gD');

  /// خادم بلاطات الخريطة (OpenStreetMap افتراضياً، بدون مفتاح)
  static const mapTilesUrl = String.fromEnvironment(
    'MAP_TILES_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// الـ schema اللي فيها جداول التوصيل داخل مشروع Supabase (لازم تكون في Exposed schemas)
  static const dbSchema = String.fromEnvironment('DB_SCHEMA', defaultValue: 'delivery');

  /// علامة مستخدمي التطبيق ده (المشروع ممكن يكون مشترك مع برامج تانية)
  static const appTag = 'talabat';

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
