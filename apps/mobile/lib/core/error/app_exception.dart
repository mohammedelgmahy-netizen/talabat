import 'package:supabase_flutter/supabase_flutter.dart';

/// خطأ موحّد للتطبيق برسالة عربية جاهزة للعرض
class AppException implements Exception {
  AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;

  /// تحويل أخطاء Supabase/الشبكة لرسالة مفهومة
  factory AppException.from(Object error) {
    if (error is AppException) return error;
    if (error is AuthException) {
      return AppException(_authMessage(error.message), code: error.statusCode);
    }
    if (error is PostgrestException) {
      // رسائل الـ raise exception في الدوال مكتوبة بالعربي أصلاً
      if (error.code == '42501') {
        return AppException(_containsArabic(error.message) ? error.message : 'غير مصرح لك بهذه العملية', code: error.code);
      }
      if (error.code == '23505') {
        return AppException('البيانات مسجلة من قبل', code: error.code);
      }
      return AppException(_containsArabic(error.message) ? error.message : 'حدث خطأ، حاول مرة أخرى', code: error.code);
    }
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return AppException('تأكد من اتصالك بالإنترنت');
    }
    return AppException('حدث خطأ غير متوقع');
  }

  static bool _containsArabic(String s) => RegExp(r'[؀-ۿ]').hasMatch(s);

  static String _authMessage(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('invalid login')) return 'البريد أو كلمة المرور غير صحيحة';
    if (m.contains('already registered')) return 'هذا البريد مسجل بالفعل';
    if (m.contains('email not confirmed')) return 'برجاء تأكيد بريدك الإلكتروني أولاً';
    if (m.contains('password')) return 'كلمة المرور ضعيفة (6 أحرف على الأقل)';
    return raw;
  }
}

/// تنفيذ عملية وتحويل أي خطأ لـ AppException
Future<T> guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } catch (e) {
    throw AppException.from(e);
  }
}
