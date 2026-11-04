import 'store_owner.dart';

abstract class StoreOwnerRepository {
  Future<List<OwnedStore>> myStores(String ownerId);

  Future<void> setOpen(String storeId, bool isOpen);

  /// الطلبات النشطة للمتجر مع تحديث لحظي لما يوصل طلب جديد
  Stream<List<StoreOrder>> watchActiveOrders(String storeId);

  Future<void> updateOrderStatus(String orderId, String status, {String? reason, int? prepMinutes});

  Future<String?> assignDriver(String orderId);
}
