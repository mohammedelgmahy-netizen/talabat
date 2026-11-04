import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/orders_repository_impl.dart';
import '../domain/order.dart';
import '../domain/orders_repository.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) => SupabaseOrdersRepository(ref.watch(supabaseProvider)));

final myOrdersProvider = StreamProvider.autoDispose<List<OrderSummary>>(
  (ref) => ref.watch(ordersRepositoryProvider).watchMyOrders(ref.watch(currentUserProvider).id),
);

final orderDetailsProvider = StreamProvider.autoDispose.family<OrderDetails, String>(
  (ref, orderId) => ref.watch(ordersRepositoryProvider).watchOrder(orderId),
);

final driverPositionProvider = StreamProvider.autoDispose.family<DriverPosition, String>(
  (ref, deliveryId) => ref.watch(ordersRepositoryProvider).watchDriverLocation(deliveryId),
);
