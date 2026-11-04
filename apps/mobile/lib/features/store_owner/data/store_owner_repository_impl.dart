import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/services/realtime.dart';
import '../../../core/utils/labels.dart';
import '../domain/store_owner.dart';
import '../domain/store_owner_repository.dart';

class SupabaseStoreOwnerRepository implements StoreOwnerRepository {
  SupabaseStoreOwnerRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OwnedStore>> myStores(String ownerId) => guard(() async {
        final rows = await _client.from('stores').select('id, name, status, is_open').eq('owner_id', ownerId).order('created_at');
        return rows.map(OwnedStore.fromJson).toList();
      });

  @override
  Future<void> setOpen(String storeId, bool isOpen) => guard(() => _client.from('stores').update({'is_open': isOpen}).eq('id', storeId));

  @override
  Stream<List<StoreOrder>> watchActiveOrders(String storeId) => liveQuery(
        client: _client,
        table: 'orders',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'store_id', value: storeId),
        fetch: () => guard(() async {
          final rows = await _client
              .from('orders')
              .select('id, order_number, status, subtotal, payment_method, placed_at, customer_notes, estimated_prep_minutes, '
                  'order_items(quantity, product_name, notes), deliveries(status)')
              .eq('store_id', storeId)
              .inFilter('status', activeOrderStatuses.toList())
              .order('placed_at');
          return rows.map(StoreOrder.fromJson).toList();
        }),
      );

  @override
  Future<void> updateOrderStatus(String orderId, String status, {String? reason, int? prepMinutes}) => guard(() => _client.from('orders').update({
        'status': status,
        'cancellation_reason': ?reason,
        'estimated_prep_minutes': ?prepMinutes,
      }).eq('id', orderId));

  @override
  Future<String?> assignDriver(String orderId) =>
      guard(() async => await _client.rpc('assign_nearest_driver', params: {'p_order_id': orderId}) as String?);
}
