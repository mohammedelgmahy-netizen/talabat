import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/device_service.dart';
import '../data/auth_repository_impl.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => SupabaseAuthRepository(ref.watch(supabaseProvider)));

enum SessionStatus { loading, signedOut, signedIn }

/// يتابع حالة تسجيل الدخول ويحمّل الملف الشخصي (الدور) — والـ Router يسمع له
class SessionController extends ChangeNotifier {
  SessionController(this._repo, this._device) {
    _sub = _repo.authChanges().listen((_) => refresh());
    refresh();
  }

  final AuthRepository _repo;
  final DeviceService _device;
  late final StreamSubscription<bool> _sub;

  SessionStatus status = SessionStatus.loading;
  AppUser? user;
  String? error;

  Future<void> refresh() async {
    if (!_repo.isSignedIn) {
      user = null;
      status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }
    try {
      final profile = await _repo.loadProfile();
      if (profile == null) {
        // حساب موجود في نفس مشروع Supabase لكنه تابع لبرنامج تاني
        error = 'الحساب ده مش مسجل في تطبيق طلبات، اعمل حساب جديد';
        await _repo.signOut();
        return;
      }
      final wasSignedIn = user != null;
      user = profile;
      error = null;
      status = SessionStatus.signedIn;
      if (!wasSignedIn) unawaited(_device.register());
    } catch (e) {
      error = e.toString();
      status = user == null ? SessionStatus.signedOut : SessionStatus.signedIn;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _device.signOut();
    await _repo.signOut();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final sessionProvider = Provider<SessionController>((ref) {
  final controller = SessionController(ref.watch(authRepositoryProvider), ref.watch(deviceServiceProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

/// المستخدم الحالي (الشاشات اللي بتستخدمه محمية بالـ Router فبيكون موجود دائماً)
final currentUserProvider = Provider<AppUser>((ref) => ref.watch(sessionProvider).user!);
