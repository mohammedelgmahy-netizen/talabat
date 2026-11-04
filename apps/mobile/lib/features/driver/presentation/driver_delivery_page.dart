import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/labels.dart';
import '../../../core/utils/launch.dart';
import '../../../core/widgets/app_map.dart';
import '../../../core/widgets/common.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_providers.dart';
import 'driver_providers.dart';

/// شاشة تنفيذ الشحنة خطوة بخطوة حتى التسليم بالـ OTP
class DriverDeliveryPage extends ConsumerWidget {
  const DriverDeliveryPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderDetailsProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: Text(order.value == null ? 'الشحنة' : 'طلب #${order.value!.orderNumber}')),
      body: order.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(orderDetailsProvider(orderId))),
        data: (o) {
          final d = o.delivery;
          if (d == null) return const EmptyView(icon: Icons.info_outline, message: 'لا توجد شحنة');
          final toStore = {'assigned', 'accepted', 'arrived_at_store'}.contains(d.status);
          final store = LatLng(o.store.latitude ?? 0, o.store.longitude ?? 0);
          final customer = LatLng(o.deliveryLatitude, o.deliveryLongitude);
          final target = toStore ? store : customer;
          final live = ref.watch(driverPositionProvider(d.id)).value;
          final me = live != null
              ? LatLng(live.latitude, live.longitude)
              : (d.driverLatitude == null ? null : LatLng(d.driverLatitude!, d.driverLongitude!));
          return Column(
            children: [
              SizedBox(
                height: 260,
                child: AppMap(
                  center: me ?? target,
                  pins: [
                    MapPin(point: store, icon: Icons.storefront, color: Colors.deepOrange),
                    MapPin(point: customer, icon: Icons.home, color: Colors.green),
                    if (me != null) MapPin(point: me, icon: Icons.navigation, color: Colors.blue, rotation: live?.heading ?? d.driverHeading),
                  ],
                  polyline: [?me, target],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: ListTile(
                        leading: Icon(toStore ? Icons.storefront : Icons.person_pin_circle, color: Theme.of(context).colorScheme.primary),
                        title: Text(toStore ? o.store.name : o.client.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(toStore ? (o.store.address ?? '') : o.addressText),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if ((toStore ? o.store.phone : o.client.phone) != null)
                            IconButton(icon: const Icon(Icons.phone), onPressed: () => callPhone((toStore ? o.store.phone : o.client.phone)!)),
                          IconButton(icon: const Icon(Icons.directions), onPressed: () => openNavigation(target.latitude, target.longitude)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(deliveryStatusLabels[d.status] ?? d.status, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            StatusChip(status: o.status),
                          ]),
                          const Divider(),
                          for (final i in o.items) Text('${i.quantity} × ${i.name}${i.notes != null ? ' (${i.notes})' : ''}'),
                          const Divider(),
                          if (o.paymentMethod == 'cash')
                            Text('حصّل من العميل: ${money(o.total)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))
                          else
                            const Text('مدفوع إلكترونياً', style: TextStyle(color: Colors.green)),
                          Text('ربحك: ${money(d.driverEarning)}'),
                          if (o.notes != null) Text('ملاحظات: ${o.notes}'),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: _ActionButtons(order: o, delivery: d))),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.order, required this.delivery});

  final OrderDetails order;
  final DeliveryInfo delivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(driverRepositoryProvider);
    Future<void> go(String status) => runWithFeedback(context, () => repo.updateStatus(delivery.id, status));

    switch (delivery.status) {
      case 'assigned':
        return FilledButton(onPressed: () => go('accepted'), child: const Text('قبول الشحنة'));
      case 'accepted':
        return FilledButton(onPressed: () => go('arrived_at_store'), child: const Text('وصلت للمتجر'));
      case 'arrived_at_store':
        final ready = order.status == 'ready_for_pickup';
        return FilledButton(
          onPressed: ready ? () => go('picked_up') : null,
          child: Text(ready ? 'استلمت الطلب' : 'في انتظار تجهيز الطلب...'),
        );
      case 'picked_up':
        return FilledButton(onPressed: () => go('on_the_way'), child: const Text('بدء التوصيل'));
      case 'on_the_way':
        return Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => go('arrived_at_customer'), child: const Text('وصلت للعميل'))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: FilledButton(onPressed: () => _deliver(context, ref), child: const Text('تسليم (OTP)'))),
        ]);
      case 'arrived_at_customer':
        return Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => _fail(context, ref),
              child: const Text('فشل التسليم'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: FilledButton(onPressed: () => _deliver(context, ref), child: const Text('تسليم (OTP)'))),
        ]);
      default:
        return FilledButton(onPressed: () => context.pop(), child: Text(deliveryStatusLabels[delivery.status] ?? 'رجوع'));
    }
  }

  Future<void> _deliver(BuildContext context, WidgetRef ref) async {
    final code = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('رمز التسليم'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('اطلب من العميل الرمز المكون من 4 أرقام الظاهر في تطبيقه'),
          const SizedBox(height: 12),
          TextField(
            controller: code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 28, letterSpacing: 12),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, code.text), child: const Text('تأكيد')),
        ],
      ),
    );
    if (entered == null || !context.mounted) return;
    await runWithFeedback(context, () async {
      final result = await ref.read(driverRepositoryProvider).verifyOtp(delivery.id, entered);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red.shade700,
      ));
      if (result.success) context.pop();
    });
  }

  Future<void> _fail(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('سبب فشل التسليم'),
        content: TextField(controller: reason, decoration: const InputDecoration(hintText: 'العميل لا يرد...')),
        actions: [FilledButton(onPressed: () => Navigator.pop(context, reason.text), child: const Text('تأكيد'))],
      ),
    );
    if (r == null || r.trim().isEmpty || !context.mounted) return;
    final ok = await runWithFeedback(context, () => ref.read(driverRepositoryProvider).updateStatus(delivery.id, 'failed', reason: r.trim()));
    if (ok && context.mounted) context.pop();
  }
}
