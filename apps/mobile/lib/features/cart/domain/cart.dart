import '../../catalog/domain/entities.dart';

class CartLine {
  const CartLine({required this.product, required this.quantity, this.notes});

  final Product product;
  final int quantity;
  final String? notes;

  double get total => product.effectivePrice * quantity;

  CartLine copyWith({int? quantity, String? notes}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity, notes: notes ?? this.notes);
}

/// السلة: من متجر واحد فقط في نفس الوقت
class Cart {
  const Cart({this.store, this.lines = const []});

  final Store? store;
  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get count => lines.fold(0, (s, l) => s + l.quantity);
  double get subtotal => lines.fold(0, (s, l) => s + l.total);
  int quantityOf(String productId) =>
      lines.where((l) => l.product.id == productId).fold(0, (s, l) => s + l.quantity);

  /// الشكل اللي بتستقبله الدالة place_order
  List<Map<String, dynamic>> toOrderItems() => [
        for (final l in lines)
          {'product_id': l.product.id, 'quantity': l.quantity, if (l.notes != null && l.notes!.isNotEmpty) 'notes': l.notes},
      ];
}
