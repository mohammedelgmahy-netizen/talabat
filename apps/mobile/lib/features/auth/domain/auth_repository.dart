import 'app_user.dart';

abstract class AuthRepository {
  bool get isSignedIn;

  /// يطلق حدثاً عند تسجيل الدخول/الخروج أو تجديد الجلسة
  Stream<bool> authChanges();

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
  });

  Future<void> signOut();

  Future<void> resetPassword(String email);

  Future<AppUser?> loadProfile();

  Future<void> updateProfile({required String fullName, String? phone});
}
