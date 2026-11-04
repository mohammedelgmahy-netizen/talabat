import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/providers.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/driver_repository_impl.dart';
import '../domain/driver.dart';
import '../domain/driver_repository.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) => SupabaseDriverRepository(ref.watch(supabaseProvider)));

final driverProfileProvider = StreamProvider<DriverProfile>(
  (ref) => ref.watch(driverRepositoryProvider).watchProfile(ref.watch(currentUserProvider).id),
);

final driverTasksProvider = StreamProvider<List<DriverTask>>(
  (ref) => ref.watch(driverRepositoryProvider).watchActiveTasks(ref.watch(currentUserProvider).id),
);

final driverSummaryProvider = FutureProvider.autoDispose<DriverSummary>((ref) {
  ref.watch(driverTasksProvider); // يتحدث بعد كل تسليم
  return ref.watch(driverRepositoryProvider).summary();
});

final driverHistoryProvider = FutureProvider.autoDispose<List<DriverTask>>(
  (ref) => ref.watch(driverRepositoryProvider).history(ref.watch(currentUserProvider).id),
);

/// يرسل موقع السائق للسيرفر طول ما هو متصل أو عنده شحنة نشطة.
/// الحد الأدنى بين كل إرسال 4 ثواني لتقليل الضغط على قاعدة البيانات.
class LocationReporter extends Notifier<bool> {
  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;
  Position? _last;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minInterval = Duration(seconds: 4);

  /// السائق الواقف ما بيبعتش تحديثات (distanceFilter)، فنبعت آخر موقع كل 30 ثانية
  /// عشان يفضل ضمن السائقين المتاحين (find_nearest_available_drivers بيشترط موقع أحدث من دقيقتين)
  static const _heartbeatInterval = Duration(seconds: 30);

  @override
  bool build() {
    final online = ref.watch(driverProfileProvider).value?.isOnline ?? false;
    final hasTasks = (ref.watch(driverTasksProvider).value ?? const []).isNotEmpty;
    final shouldRun = online || hasTasks;
    ref.onDispose(_stop);
    if (shouldRun) {
      _start();
    }
    return shouldRun;
  }

  Future<void> _start() async {
    if (_sub != null) return;
    final location = ref.read(locationServiceProvider);
    try {
      await location.ensurePermission();
    } catch (e) {
      debugPrint('location permission: $e');
      return;
    }
    final repo = ref.read(driverRepositoryProvider);

    void send(Position p) {
      _lastSent = DateTime.now();
      repo
          .reportLocation(
            latitude: p.latitude,
            longitude: p.longitude,
            heading: p.heading,
            speedKmh: p.speed * 3.6,
            accuracyM: p.accuracy,
          )
          .catchError((Object e) => debugPrint('report location failed: $e'));
    }

    _sub = location.track().listen((p) {
      _last = p;
      if (DateTime.now().difference(_lastSent) >= _minInterval) send(p);
    });
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      if (_last != null && DateTime.now().difference(_lastSent) >= _heartbeatInterval) send(_last!);
    });
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
  }
}

final locationReporterProvider = NotifierProvider<LocationReporter, bool>(LocationReporter.new);
