import 'package:flutter/material.dart';

/// النصوص العربية لحالات الطلب والشحنة (نفس قيم الـ Enums في قاعدة البيانات)
const orderStatusLabels = <String, String>{
  'pending': 'في انتظار المتجر',
  'accepted': 'تم قبول الطلب',
  'preparing': 'جاري التحضير',
  'ready_for_pickup': 'جاهز للاستلام',
  'picked_up': 'استلمه السائق',
  'on_the_way': 'في الطريق إليك',
  'delivered': 'تم التسليم',
  'rejected': 'رفضه المتجر',
  'cancelled': 'ملغي',
};

const deliveryStatusLabels = <String, String>{
  'assigned': 'شحنة جديدة',
  'accepted': 'متجه للمتجر',
  'arrived_at_store': 'وصلت للمتجر',
  'picked_up': 'تم الاستلام',
  'on_the_way': 'في الطريق للعميل',
  'arrived_at_customer': 'وصلت للعميل',
  'delivered': 'تم التسليم',
  'failed': 'فشل التسليم',
  'cancelled': 'ملغاة',
};

const paymentMethodLabels = <String, String>{
  'cash': 'كاش عند الاستلام',
  'card': 'بطاقة',
  'wallet': 'محفظة',
};

const activeOrderStatuses = {'pending', 'accepted', 'preparing', 'ready_for_pickup', 'picked_up', 'on_the_way'};
const activeDeliveryStatuses = {'assigned', 'accepted', 'arrived_at_store', 'picked_up', 'on_the_way', 'arrived_at_customer'};

Color orderStatusColor(String status) {
  switch (status) {
    case 'pending':
      return Colors.orange;
    case 'accepted':
    case 'preparing':
      return Colors.blue;
    case 'ready_for_pickup':
      return Colors.indigo;
    case 'picked_up':
    case 'on_the_way':
      return Colors.teal;
    case 'delivered':
      return Colors.green;
    default:
      return Colors.red;
  }
}
