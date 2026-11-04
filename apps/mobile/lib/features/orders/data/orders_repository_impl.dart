import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide toDouble;

import '../../../core/config/env.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/services/realtime.dart';
import '../../../core/utils/json.dart';
import '../domain/order.dart';
import '../domain/orders_repository.dart';

class SupabaseOrdersRepository implements OrdersRepository {
  SupabaseOrdersRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> placeOrder({
    required String storeId,
    required String addressId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    String? notes,
  }) =>
      guard(() async {
        final id = await _client.rpc('place_order', params: {
          'p_store_id': storeId,
          'p_address_id': addressId,
          'p_items': items,
          'p_payment_method': paymentMethod,
          'p_notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
        });
        return id as String;
      });

  @override
  Stream<List<OrderSummary>> watchMyOrders(String clientId) => liveQuery(
        client: _client,
        table: 'orders',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'client_id', value: clientId),
        fetch: () => guard(() async {
          final rows = await _client
              .from('orders')
              .select('id, order_number, status, total_amount, placed_at, stores(name, logo_url), order_items(quantity)')
              .eq('client_id', clientId)
              .order('placed_at', ascending: false)
              .limit(100);
          return rows.map(OrderSummary.fromJson).toList();
        }),
      );

  @override
  Future<OrderDetails> getOrder(String orderId) => guard(() async {
        final json = await _client.rpc('get_order_details', params: {'p_order_id': orderId});
        if (json == null) throw AppException('الطلب غير موجود');
        return OrderDetails.fromJson(json as Map<String, dynamic>);
      });

  @override
  Stream<OrderDetails> watchOrder(String orderId) {
    // نسمع لتغييرات الطلب نفسه والشحنات المرتبطة به
    final orderStream = liveQuery(
      client: _client,
      table: 'orders',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: orderId),
      fetch: () => getOrder(orderId),
    );
    final deliveryChanges = liveQuery(
      client: _client,
      table: 'deliveries',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'order_id', value: orderId),
      fetch: () async => DateTime.now(),
    );
    late StreamController<OrderDetails> controller;
    final subs = <StreamSubscription<dynamic>>[];
    controller = StreamController<OrderDetails>(
      onListen: () {
        subs.add(orderStream.listen(controller.add, onError: controller.addError));
        var first = true;
        subs.add(deliveryChanges.listen((_) async {
          if (first) {
            first = false;
            return;
          }
          try {
            controller.add(await getOrder(orderId));
          } catch (e, st) {
            controller.addError(e, st);
          }
        }));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) =>
      guard(() => _client.rpc('cancel_my_order', params: {'p_order_id': orderId, 'p_reason': reason}));

  @override
  Future<String> issueDeliveryOtp(String deliveryId) =>
      guard(() async => (await _client.rpc('issue_delivery_otp', params: {'p_delivery_id': deliveryId})) as String);

  @override
  Stream<DriverPosition> watchDriverLocation(String deliveryId) {
    late StreamController<DriverPosition> controller;
    RealtimeChannel? channel;
    controller = StreamController<DriverPosition>(
      onListen: () {
        channel = _client
            .channel('driver-location:$deliveryId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: Env.dbSchema,
              table: 'driver_locations',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'delivery_id', value: deliveryId),
              callback: (payload) {
                final r = payload.newRecord;
                controller.add(DriverPosition(
                  latitude: toDouble(r['latitude']),
                  longitude: toDouble(r['longitude']),
                  heading: toDoubleOrNull(r['heading']),
                ));
              },
            )
            .subscribe();
      },
      onCancel: () async {
        if (channel != null) await _client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }
}
