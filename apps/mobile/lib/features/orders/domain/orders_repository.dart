import 'order.dart';

abstract class OrdersRepository {
  /// إنشاء الطلب عبر place_order (الأسعار تُحسب في السيرفر)
  Future<String> placeOrder({
    required String storeId,
    required String addressId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    String? notes,
  });

  Stream<List<OrderSummary>> watchMyOrders(String clientId);

  /// تفاصيل الطلب، وتتحدث لحظياً عند تغير الطلب أو الشحنة
  Stream<OrderDetails> watchOrder(String orderId);

  Future<OrderDetails> getOrder(String orderId);

  Future<void> cancelOrder(String orderId, {String? reason});

  /// يولد رمز OTP جديد يعرضه العميل للسائق عند الاستلام
  Future<String> issueDeliveryOtp(String deliveryId);

  Stream<DriverPosition> watchDriverLocation(String deliveryId);
}
