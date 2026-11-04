import 'driver.dart';

abstract class DriverRepository {
  Stream<DriverProfile> watchProfile(String driverId);

  Future<void> setAvailability(String driverId, String availability);

  /// الشحنات النشطة للسائق (تتحدث لحظياً عند إسناد شحنة جديدة)
  Stream<List<DriverTask>> watchActiveTasks(String driverId);

  Future<List<DriverTask>> history(String driverId);

  Future<void> updateStatus(String deliveryId, String status, {String? reason});

  Future<OtpResult> verifyOtp(String deliveryId, String code);

  Future<void> reportLocation({required double latitude, required double longitude, double? heading, double? speedKmh, double? accuracyM});

  Future<DriverSummary> summary();
}
