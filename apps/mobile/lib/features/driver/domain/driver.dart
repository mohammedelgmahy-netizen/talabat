import '../../../core/utils/json.dart';

class DriverProfile {
  const DriverProfile({
    required this.availability,
    required this.isVerified,
    required this.vehicleType,
    required this.rating,
    required this.totalDeliveries,
    this.vehiclePlate,
  });

  final String availability; // offline | online | busy | on_break
  final bool isVerified;
  final String vehicleType;
  final String? vehiclePlate;
  final double rating;
  final int totalDeliveries;

  bool get isOnline => availability == 'online' || availability == 'busy';

  factory DriverProfile.fromJson(Map<String, dynamic> j) => DriverProfile(
        availability: j['availability'] as String,
        isVerified: j['is_verified'] == true,
        vehicleType: j['vehicle_type'] as String,
        vehiclePlate: j['vehicle_plate'] as String?,
        rating: toDouble(j['rating']),
        totalDeliveries: toInt(j['total_deliveries']),
      );
}

/// شحنة مسندة للسائق مع ملخص الطلب
class DriverTask {
  const DriverTask({
    required this.id,
    required this.status,
    required this.orderId,
    required this.orderNumber,
    required this.orderStatus,
    required this.storeName,
    required this.storeAddress,
    required this.dropoffAddress,
    required this.orderTotal,
    required this.paymentMethod,
    required this.earning,
    required this.distanceToStoreM,
    required this.assignedAt,
  });

  final String id;
  final String status;
  final String orderId;
  final int orderNumber;
  final String orderStatus;
  final String storeName;
  final String storeAddress;
  final String dropoffAddress;
  final double orderTotal;
  final String paymentMethod;
  final double earning;
  final int? distanceToStoreM;
  final DateTime? assignedAt;

  bool get isNew => status == 'assigned';

  factory DriverTask.fromJson(Map<String, dynamic> j) {
    final o = j['orders'] as Map<String, dynamic>;
    final s = o['stores'] as Map<String, dynamic>?;
    return DriverTask(
      id: j['id'] as String,
      status: j['status'] as String,
      orderId: o['id'] as String,
      orderNumber: toInt(o['order_number']),
      orderStatus: o['status'] as String,
      storeName: (s?['name'] as String?) ?? '',
      storeAddress: (s?['address_line'] as String?) ?? '',
      dropoffAddress: o['delivery_address_text'] as String,
      orderTotal: toDouble(o['total_amount']),
      paymentMethod: o['payment_method'] as String,
      earning: toDouble(j['driver_earning']),
      distanceToStoreM: j['distance_to_store_m'] as int?,
      assignedAt: toDate(j['assigned_at']),
    );
  }
}

class DriverSummary {
  const DriverSummary({
    required this.todayEarnings,
    required this.todayDeliveries,
    required this.weekEarnings,
    required this.weekDeliveries,
    required this.totalEarnings,
    required this.cashToCollect,
  });

  final double todayEarnings;
  final int todayDeliveries;
  final double weekEarnings;
  final int weekDeliveries;
  final double totalEarnings;
  final double cashToCollect;

  factory DriverSummary.fromJson(Map<String, dynamic> j) => DriverSummary(
        todayEarnings: toDouble(j['today_earnings']),
        todayDeliveries: toInt(j['today_deliveries']),
        weekEarnings: toDouble(j['week_earnings']),
        weekDeliveries: toInt(j['week_deliveries']),
        totalEarnings: toDouble(j['total_earnings']),
        cashToCollect: toDouble(j['cash_to_collect']),
      );
}

/// نتيجة التحقق من رمز التسليم (verify_delivery_otp)
class OtpResult {
  const OtpResult({required this.success, this.error, this.remainingAttempts});

  final bool success;
  final String? error;
  final int? remainingAttempts;

  String get message {
    if (success) return 'تم تأكيد التسليم';
    switch (error) {
      case 'wrong_code':
        return 'الرمز غير صحيح، متبقي ${remainingAttempts ?? 0} محاولات';
      case 'otp_expired':
        return 'انتهت صلاحية الرمز، اطلب من العميل رمزاً جديداً';
      case 'too_many_attempts':
        return 'محاولات كثيرة خاطئة، اطلب من العميل رمزاً جديداً';
      case 'no_active_otp':
        return 'العميل لم يُظهر الرمز بعد، اطلب منه فتح صفحة الطلب';
      case 'invalid_code_format':
        return 'الرمز مكون من 4 أرقام';
      case 'invalid_delivery_status':
        return 'لا يمكن التسليم في هذه المرحلة';
      default:
        return 'تعذر التحقق من الرمز';
    }
  }

  factory OtpResult.fromJson(Map<String, dynamic> j) => OtpResult(
        success: j['success'] == true,
        error: j['error'] as String?,
        remainingAttempts: j['remaining_attempts'] as int?,
      );
}
