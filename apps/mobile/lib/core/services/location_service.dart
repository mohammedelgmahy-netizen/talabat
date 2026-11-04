import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../error/app_exception.dart';

/// خدمة الموقع: الصلاحيات + الموقع الحالي + البث المستمر (للسائق)
class LocationService {
  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw AppException('برجاء تشغيل خدمة الموقع (GPS)');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw AppException('التطبيق يحتاج صلاحية الوصول للموقع');
    }
  }

  Future<LatLng> current() async {
    await ensurePermission();
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LatLng(p.latitude, p.longitude);
  }

  /// بث الموقع كل ما السائق يتحرك 10 متر على الأقل
  Stream<Position> track() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      );
}
