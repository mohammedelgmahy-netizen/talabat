import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/common.dart';
import '../../addresses/presentation/address_providers.dart';
import '../../orders/presentation/order_providers.dart';
import 'cart_controller.dart';

/// السلة وإتمام الطلب. الإجمالي النهائي يُحسب في السيرفر (place_order)
class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  final _notes = TextEditingController();
  String _payment = 'cash';
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    final address = ref.read(selectedAddressProvider);
    if (address == null) {
      await context.push('/client/addresses/new');
      ref.invalidate(addressesProvider);
      return;
    }
    setState(() => _busy = true);
    String? orderId;
    final ok = await runWithFeedback(context, () async {
      orderId = await ref.read(ordersRepositoryProvider).placeOrder(
            storeId: cart.store!.id,
            addressId: address.id!,
            items: cart.toOrderItems(),
            paymentMethod: _payment,
            notes: _notes.text,
          );
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && orderId != null) {
      ref.read(cartProvider.notifier).clear();
      context.go('/client/orders/$orderId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final address = ref.watch(selectedAddressProvider);
    final store = cart.store;

    if (cart.isEmpty || store == null) {
      return Scaffold(appBar: AppBar(title: const Text('السلة')), body: const EmptyView(icon: Icons.shopping_bag_outlined, message: 'السلة فارغة'));
    }
    final belowMin = cart.subtotal < store.minOrderAmount;
    final estimatedTotal = cart.subtotal + store.deliveryFee;

    return Scaffold(
      appBar: AppBar(title: Text('السلة - ${store.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(children: [
              for (final l in cart.lines)
                ListTile(
                  title: Text(l.product.name),
                  subtitle: Text(l.notes?.isNotEmpty == true ? l.notes! : money(l.product.effectivePrice)),
                  leading: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => ref.read(cartProvider.notifier).decrement(l.product.id)),
                    Text('${l.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => ref.read(cartProvider.notifier).add(store, l.product)),
                  ]),
                  trailing: Text(money(l.total)),
                  onLongPress: () => _editNotes(l.product.id, l.notes),
                ),
            ]),
          ),
          const SectionTitle('التوصيل إلى'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(address?.labelText ?? 'أضف عنوان التوصيل'),
              subtitle: address == null ? null : Text(address.fullText),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => context.push(address == null ? '/client/addresses/new' : '/client/addresses/select'),
            ),
          ),
          const SectionTitle('طريقة الدفع'),
          Card(
            child: RadioGroup<String>(
              groupValue: _payment,
              onChanged: (v) => setState(() => _payment = v ?? 'cash'),
              child: Column(children: [
                for (final m in const ['cash', 'card', 'wallet'])
                  RadioListTile<String>(value: m, title: Text(paymentMethodLabels[m]!)),
              ]),
            ),
          ),
          const SectionTitle('ملاحظات للمتجر'),
          TextField(controller: _notes, maxLength: 500, maxLines: 2, decoration: const InputDecoration(hintText: 'مثلاً: بدون بصل')),
          const SectionTitle('ملخص الفاتورة'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _row('المنتجات', money(cart.subtotal)),
                _row('التوصيل (تقريبي)', money(store.deliveryFee)),
                const Divider(),
                _row('الإجمالي التقريبي', money(estimatedTotal), bold: true),
                const SizedBox(height: 6),
                const Text('رسوم الخدمة والضريبة تُضاف حسب إعدادات المنصة ويظهر الإجمالي النهائي بعد التأكيد.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
          ),
          if (belowMin)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('الحد الأدنى للطلب ${money(store.minOrderAmount)}', style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _busy || belowMin ? null : _checkout,
            child: _busy
                ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(address == null ? 'أضف عنوان التوصيل' : 'تأكيد الطلب'),
          ),
        ),
      ),
    );
  }

  Future<void> _editNotes(String productId, String? current) async {
    final c = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ملاحظة على الصنف'),
        content: TextField(controller: c, maxLength: 300, autofocus: true),
        actions: [FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('حفظ'))],
      ),
    );
    if (result != null) ref.read(cartProvider.notifier).setNotes(productId, result);
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null))),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        ]),
      );
}
