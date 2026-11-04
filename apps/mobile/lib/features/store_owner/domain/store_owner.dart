import '../../../core/utils/json.dart';

class OwnedStore {
  const OwnedStore({required this.id, required this.name, required this.status, required this.isOpen});

  final String id;
  final String name;
  final String status; // pending_approval | active | suspended | closed
  final bool isOpen;

  factory OwnedStore.fromJson(Map<String, dynamic> j) =>
      OwnedStore(id: j['id'] as String, name: j['name'] as String, status: j['status'] as String, isOpen: j['is_open'] == true);
}

class StoreOrder {
  const StoreOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.paymentMethod,
    required this.placedAt,
    required this.items,
    required this.hasDriver,
    this.notes,
    this.prepMinutes,
    this.driverStatus,
  });

  final String id;
  final int orderNumber;
  final String status;
  final double subtotal;
  final String paymentMethod;
  final DateTime? placedAt;
  final List<(int, String, String?)> items; // (الكمية، الاسم، ملاحظات)
  final bool hasDriver;
  final String? driverStatus;
  final String? notes;
  final int? prepMinutes;

  factory StoreOrder.fromJson(Map<String, dynamic> j) {
    final deliveries = ((j['deliveries'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>()
        .where((d) => !{'cancelled', 'failed'}.contains(d['status']))
        .toList();
    return StoreOrder(
      id: j['id'] as String,
      orderNumber: toInt(j['order_number']),
      status: j['status'] as String,
      subtotal: toDouble(j['subtotal']),
      paymentMethod: j['payment_method'] as String,
      placedAt: toDate(j['placed_at']),
      notes: j['customer_notes'] as String?,
      prepMinutes: j['estimated_prep_minutes'] as int?,
      items: [
        for (final i in ((j['order_items'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>())
          (toInt(i['quantity']), i['product_name'] as String, i['notes'] as String?),
      ],
      hasDriver: deliveries.isNotEmpty,
      driverStatus: deliveries.isEmpty ? null : deliveries.first['status'] as String?,
    );
  }
}
