import 'package:delivery_app/features/cart/domain/cart.dart';
import 'package:delivery_app/features/catalog/domain/entities.dart';
import 'package:delivery_app/features/driver/domain/driver.dart';
import 'package:delivery_app/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';

Product product(String id, double price, {double? discounted}) =>
    Product(id: id, storeId: 's1', name: 'p$id', price: price, discountedPrice: discounted, status: 'active');

void main() {
  test('cart totals use discounted price and build place_order payload', () {
    final cart = Cart(lines: [
      CartLine(product: product('1', 50), quantity: 2),
      CartLine(product: product('2', 30, discounted: 20), quantity: 1, notes: 'بدون بصل'),
    ]);
    expect(cart.count, 3);
    expect(cart.subtotal, 120);
    expect(cart.toOrderItems(), [
      {'product_id': '1', 'quantity': 2},
      {'product_id': '2', 'quantity': 1, 'notes': 'بدون بصل'},
    ]);
  });

  test('order details parse get_order_details json', () {
    final o = OrderDetails.fromJson({
      'id': 'o1',
      'order_number': 100001,
      'status': 'on_the_way',
      'subtotal': '100.00',
      'delivery_fee': 14.42,
      'service_fee': 3,
      'discount_amount': 0,
      'tax_amount': 0,
      'total_amount': 117.42,
      'payment_method': 'cash',
      'payment_status': 'pending',
      'delivery_address_text': 'Street 1',
      'delivery_latitude': 30.06,
      'delivery_longitude': 31.25,
      'client': {'id': 'c', 'full_name': 'Client', 'phone': null},
      'store': {'id': 's', 'name': 'Koshary', 'latitude': 30.04, 'longitude': 31.23},
      'items': [
        {'product_name': 'Koshary', 'unit_price': 50, 'quantity': 2, 'line_total': 100, 'notes': null},
      ],
      'delivery': {'id': 'd', 'status': 'on_the_way', 'driver_id': 'x', 'driver_name': 'Driver', 'driver_latitude': 30.05, 'driver_longitude': 31.24},
    });
    expect(o.subtotal, 100);
    expect(o.items.single.quantity, 2);
    expect(o.delivery!.isActive, isTrue);
    expect(o.isFinished, isFalse);
  });

  test('otp result messages', () {
    expect(OtpResult.fromJson({'success': true}).message, 'تم تأكيد التسليم');
    expect(OtpResult.fromJson({'success': false, 'error': 'wrong_code', 'remaining_attempts': 2}).message, contains('2'));
  });
}
