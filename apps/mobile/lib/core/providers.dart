import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/device_service.dart';
import 'services/location_service.dart';

/// مزودات البنية الأساسية (Dependency Injection)
final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final pushTokenSourceProvider = Provider<PushTokenSource>((ref) => NoPushTokenSource());

final deviceServiceProvider = Provider<DeviceService>(
  (ref) => DeviceService(ref.watch(supabaseProvider), ref.watch(pushTokenSourceProvider)),
);
