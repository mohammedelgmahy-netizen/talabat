import '../../../core/utils/json.dart';

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.placedAt,
    required this.storeName,
    this.storeLogo,
    this.itemsCount = 0,
  });

  final String id;
  final int orderNumber;
  final String status;
  final double totalAmount;
  final DateTime? placedAt;
  final String storeName;
  final String? storeLogo;
  final int itemsCount;

  factory OrderSummary.fromJson(Map<String, dynamic> j) {
    final store = j['stores'] as Map<String, dynamic>?;
    final items = j['order_items'] as List<dynamic>?;
    return OrderSummary(
      id: j['id'] as String,
      orderNumber: toInt(j['order_number']),
      status: j['status'] as String,
      totalAmount: toDouble(j['total_amount']),
      placedAt: toDate(j['placed_at']),
      storeName: (store?['name'] as String?) ?? '',
      storeLogo: store?['logo_url'] as String?,
      itemsCount: items == null ? 0 : items.fold<int>(0, (s, e) => s + toInt((e as Map)['quantity'])),
    );
  }
}

class OrderItem {
  const OrderItem({required this.name, required this.unitPrice, required this.quantity, required this.lineTotal, this.notes});

  final String name;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final String? notes;

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        name: j['product_name'] as String,
        unitPrice: toDouble(j['unit_price']),
        quantity: toInt(j['quantity']),
        lineTotal: toDouble(j['line_total']),
        notes: j['notes'] as String?,
      );
}

class Party {
  const Party({required this.id, required this.name, this.phone, this.latitude, this.longitude, this.address});

  final String id;
  final String name;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final String? address;
}

class DeliveryInfo {
  const DeliveryInfo({
    required this.id,
    required this.status,
    required this.driverId,
    required this.driverName,
    this.driverPhone,
    this.vehicleType,
    this.vehiclePlate,
    this.driverLatitude,
    this.driverLongitude,
    this.driverHeading,
    this.driverEarning = 0,
  });

  final String id;
  final String status;
  final String driverId;
  final String driverName;
  final String? driverPhone;
  final String? vehicleType;
  final String? vehiclePlate;
  final double? driverLatitude;
  final double? driverLongitude;
  final double? driverHeading;
  final double driverEarning;

  bool get isActive => !{'delivered', 'failed', 'cancelled'}.contains(status);

  factory DeliveryInfo.fromJson(Map<String, dynamic> j) => DeliveryInfo(
        id: j['id'] as String,
        status: j['status'] as String,
        driverId: j['driver_id'] as String,
        driverName: (j['driver_name'] as String?) ?? '',
        driverPhone: j['driver_phone'] as String?,
        vehicleType: j['vehicle_type'] as String?,
        vehiclePlate: j['vehicle_plate'] as String?,
        driverLatitude: toDoubleOrNull(j['driver_latitude']),
        driverLongitude: toDoubleOrNull(j['driver_longitude']),
        driverHeading: toDoubleOrNull(j['driver_heading']),
        driverEarning: toDouble(j['driver_earning']),
      );
}

class OrderDetails {
  const OrderDetails({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.addressText,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.client,
    required this.store,
    required this.items,
    this.delivery,
    this.notes,
    this.prepMinutes,
    this.placedAt,
    this.deliveredAt,
    this.cancellationReason,
    this.distanceKm,
  });

  final String id;
  final int orderNumber;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double discount;
  final double tax;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String addressText;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final Party client;
  final Party store;
  final List<OrderItem> items;
  final DeliveryInfo? delivery;
  final String? notes;
  final int? prepMinutes;
  final DateTime? placedAt;
  final DateTime? deliveredAt;
  final String? cancellationReason;
  final double? distanceKm;

  bool get isFinished => {'delivered', 'rejected', 'cancelled'}.contains(status);

  factory OrderDetails.fromJson(Map<String, dynamic> j) {
    final c = j['client'] as Map<String, dynamic>;
    final s = j['store'] as Map<String, dynamic>;
    return OrderDetails(
      id: j['id'] as String,
      orderNumber: toInt(j['order_number']),
      status: j['status'] as String,
      subtotal: toDouble(j['subtotal']),
      deliveryFee: toDouble(j['delivery_fee']),
      serviceFee: toDouble(j['service_fee']),
      discount: toDouble(j['discount_amount']),
      tax: toDouble(j['tax_amount']),
      total: toDouble(j['total_amount']),
      paymentMethod: j['payment_method'] as String,
      paymentStatus: j['payment_status'] as String,
      addressText: j['delivery_address_text'] as String,
      deliveryLatitude: toDouble(j['delivery_latitude']),
      deliveryLongitude: toDouble(j['delivery_longitude']),
      client: Party(id: c['id'] as String, name: (c['full_name'] as String?) ?? '', phone: c['phone'] as String?),
      store: Party(
        id: s['id'] as String,
        name: s['name'] as String,
        phone: s['phone'] as String?,
        latitude: toDoubleOrNull(s['latitude']),
        longitude: toDoubleOrNull(s['longitude']),
        address: s['address_line'] as String?,
      ),
      items: ((j['items'] as List<dynamic>?) ?? []).map((e) => OrderItem.fromJson(e as Map<String, dynamic>)).toList(),
      delivery: j['delivery'] == null ? null : DeliveryInfo.fromJson(j['delivery'] as Map<String, dynamic>),
      notes: j['customer_notes'] as String?,
      prepMinutes: j['estimated_prep_minutes'] as int?,
      placedAt: toDate(j['placed_at']),
      deliveredAt: toDate(j['delivered_at']),
      cancellationReason: j['cancellation_reason'] as String?,
      distanceKm: toDoubleOrNull(j['distance_km']),
    );
  }
}

/// نقطة تتبع للسائق قادمة لحظياً من driver_locations
class DriverPosition {
  const DriverPosition({required this.latitude, required this.longitude, this.heading});

  final double latitude;
  final double longitude;
  final double? heading;
}
