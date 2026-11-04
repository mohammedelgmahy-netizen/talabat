import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/error/app_exception.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  Stream<bool> authChanges() => _client.auth.onAuthStateChange.map((s) => s.session != null);

  @override
  Future<void> signIn({required String email, required String password}) =>
      guard(() => _client.auth.signInWithPassword(email: email.trim(), password: password));

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
  }) {
    if (role == UserRole.admin) throw AppException('لا يمكن التسجيل كمدير');
    // الـ trigger handle_new_auth_user ينشئ profiles (و drivers للسائق) من الـ metadata
    return guard(() => _client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {'app': Env.appTag, 'full_name': fullName.trim(), 'phone': phone.trim(), 'role': role.value},
        ));
  }

  @override
  Future<void> signOut() => guard(() => _client.auth.signOut());

  @override
  Future<void> resetPassword(String email) => guard(() => _client.auth.resetPasswordForEmail(email.trim()));

  @override
  Future<AppUser?> loadProfile() => guard(() async {
        final uid = _client.auth.currentUser?.id;
        if (uid == null) return null;
        final row = await _client.from('profiles').select().eq('id', uid).maybeSingle();
        return row == null ? null : AppUser.fromJson(row);
      });

  @override
  Future<void> updateProfile({required String fullName, String? phone}) => guard(() async {
        final uid = _client.auth.currentUser!.id;
        await _client.from('profiles').update({
          'full_name': fullName.trim(),
          'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
        }).eq('id', uid);
      });
}
