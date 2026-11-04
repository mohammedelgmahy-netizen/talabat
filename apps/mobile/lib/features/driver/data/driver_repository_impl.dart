import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/services/realtime.dart';
import '../../../core/utils/labels.dart';
import '../domain/driver.dart';
import '../domain/driver_repository.dart';

class SupabaseDriverRepository implements DriverRepository {
  SupabaseDriverRepository(this._client);

  final SupabaseClient _client;

  static const _taskSelect =
      'id, status, driver_earning, distance_to_store_m, assigned_at, '
      'orders(id, order_number, status, delivery_address_text, total_amount, payment_method, stores(name, address_line))';

  @override
  Stream<DriverProfile> watchProfile(String driverId) => _client
      .from('drivers')
      .stream(primaryKey: ['user_id'])
      .eq('user_id', driverId)
      .where((rows) => rows.isNotEmpty)
      .map((rows) => DriverProfile.fromJson(rows.first));

  @override
  Future<void> setAvailability(String driverId, String availability) =>
      guard(() => _client.from('drivers').update({'availability': availability}).eq('user_id', driverId));

  @override
  Stream<List<DriverTask>> watchActiveTasks(String driverId) => liveQuery(
        client: _client,
        table: 'deliveries',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'driver_id', value: driverId),
        fetch: () => guard(() async {
          final rows = await _client
              .from('deliveries')
              .select(_taskSelect)
              .eq('driver_id', driverId)
              .inFilter('status', activeDeliveryStatuses.toList())
              .order('assigned_at');
          return rows.map(DriverTask.fromJson).toList();
        }),
      );

  @override
  Future<List<DriverTask>> history(String driverId) => guard(() async {
        final rows = await _client
            .from('deliveries')
            .select(_taskSelect)
            .eq('driver_id', driverId)
            .inFilter('status', ['delivered', 'failed', 'cancelled'])
            .order('assigned_at', ascending: false)
            .limit(100);
        return rows.map(DriverTask.fromJson).toList();
      });

  @override
  Future<void> updateStatus(String deliveryId, String status, {String? reason}) => guard(() => _client
      .from('deliveries')
      .update({'status': status, 'failure_reason': ?reason}).eq('id', deliveryId));

  @override
  Future<OtpResult> verifyOtp(String deliveryId, String code) => guard(() async {
        final json = await _client.rpc('verify_delivery_otp', params: {'p_delivery_id': deliveryId, 'p_code': code.trim()});
        return OtpResult.fromJson(json as Map<String, dynamic>);
      });

  @override
  Future<void> reportLocation({required double latitude, required double longitude, double? heading, double? speedKmh, double? accuracyM}) =>
      _client.rpc('report_driver_location', params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_heading': (heading == null || heading < 0) ? null : heading % 360,
        'p_speed_kmh': (speedKmh == null || speedKmh < 0) ? null : speedKmh.clamp(0, 300),
        'p_accuracy_m': (accuracyM == null || accuracyM < 0) ? null : accuracyM,
      });

  @override
  Future<DriverSummary> summary() => guard(() async {
        final json = await _client.rpc('my_driver_summary');
        return DriverSummary.fromJson(json as Map<String, dynamic>);
      });
}
