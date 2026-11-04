import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'providers.dart';

/// منطقة الشغل اللي صاحب البرنامج بيحددها من لوحة التحكم (الافتراضي برج العرب)
class ServiceArea {
  const ServiceArea({required this.name, required this.center, required this.radiusKm});

  final String name;
  final LatLng center;
  final double radiusKm;

  static const fallback = ServiceArea(name: 'برج العرب - الإسكندرية', center: LatLng(30.895, 29.59), radiusKm: 20);

  bool contains(LatLng p) => const Distance().as(LengthUnit.Kilometer, center, p) <= radiusKm;
}

final serviceAreaProvider = FutureProvider<ServiceArea>((ref) async {
  try {
    final row = await ref
        .watch(supabaseProvider)
        .from('platform_settings')
        .select('service_area_name, service_center_lat, service_center_lng, service_radius_km')
        .single();
    return ServiceArea(
      name: row['service_area_name'] as String,
      center: LatLng((row['service_center_lat'] as num).toDouble(), (row['service_center_lng'] as num).toDouble()),
      radiusKm: (row['service_radius_km'] as num).toDouble(),
    );
  } catch (_) {
    return ServiceArea.fallback;
  }
});
