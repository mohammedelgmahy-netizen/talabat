import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// مصدر رمز الإشعارات. الافتراضي لا يرجع رمزاً؛ عند إضافة Firebase
/// استبدله بتنفيذ يستخدم FirebaseMessaging.instance.getToken() (راجع README).
abstract class PushTokenSource {
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
}

class NoPushTokenSource implements PushTokenSource {
  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

/// تسجيل الجهاز في user_sessions و fcm_tokens عبر الدالة register_device
class DeviceService {
  DeviceService(this._client, this._push);

  final SupabaseClient _client;
  final PushTokenSource _push;
  static const _deviceKey = 'device_id';
  static const appVersion = '1.0.0';

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceKey, id);
    }
    return id;
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }

  Future<void> register() async {
    if (_client.auth.currentUser == null) return;
    try {
      await _client.rpc('register_device', params: {
        'p_device_id': await deviceId(),
        'p_platform': _platform,
        'p_fcm_token': await _push.getToken(),
        'p_device_model': kIsWeb ? 'web' : Platform.operatingSystem,
        'p_app_version': appVersion,
      });
    } catch (e) {
      debugPrint('register_device failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.rpc('sign_out_device', params: {'p_device_id': await deviceId()});
    } catch (e) {
      debugPrint('sign_out_device failed: $e');
    }
  }
}
