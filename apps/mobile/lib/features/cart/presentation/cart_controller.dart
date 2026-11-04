import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalog/domain/entities.dart';
import '../domain/cart.dart';

class CartController extends Notifier<Cart> {
  @override
  Cart build() => const Cart();

  /// يرجع false لو المنتج من متجر مختلف عن السلة الحالية
  bool add(Store store, Product product) {
    if (state.store != null && state.store!.id != store.id && !state.isEmpty) return false;
    final lines = [...state.lines];
    final i = lines.indexWhere((l) => l.product.id == product.id);
    if (i >= 0) {
      if (lines[i].quantity >= 99) return true;
      lines[i] = lines[i].copyWith(quantity: lines[i].quantity + 1);
    } else {
      lines.add(CartLine(product: product, quantity: 1));
    }
    state = Cart(store: store, lines: lines);
    return true;
  }

  void decrement(String productId) {
    final lines = [...state.lines];
    final i = lines.indexWhere((l) => l.product.id == productId);
    if (i < 0) return;
    if (lines[i].quantity <= 1) {
      lines.removeAt(i);
    } else {
      lines[i] = lines[i].copyWith(quantity: lines[i].quantity - 1);
    }
    state = lines.isEmpty ? const Cart() : Cart(store: state.store, lines: lines);
  }

  void setNotes(String productId, String notes) {
    state = Cart(
      store: state.store,
      lines: [for (final l in state.lines) l.product.id == productId ? l.copyWith(notes: notes) : l],
    );
  }

  void replaceWith(Store store, Product product) {
    state = Cart(store: store, lines: [CartLine(product: product, quantity: 1)]);
  }

  void clear() => state = const Cart();
}

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);
