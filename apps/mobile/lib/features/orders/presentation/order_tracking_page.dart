import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/labels.dart';
import '../../../core/utils/launch.dart';
import '../../../core/widgets/app_map.dart';
import '../../../core/widgets/common.dart';
import '../domain/order.dart';
import 'order_providers.dart';

/// تتبع الطلب لحظياً: الحالة + موقع السائق على الخريطة + رمز التسليم OTP
class OrderTrackingPage extends ConsumerWidget {
  const OrderTrackingPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderDetailsProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: Text(order.value == null ? 'تفاصيل الطلب' : 'طلب #${order.value!.orderNumber}')),
      body: order.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(orderDetailsProvider(orderId))),
        data: (o) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusHeader(order: o),
            if (o.delivery != null && o.delivery!.isActive) ...[
              const SizedBox(height: 12),
              _LiveMap(order: o),
              const SizedBox(height: 12),
              _DriverCard(delivery: o.delivery!),
              if ({'picked_up', 'on_the_way', 'arrived_at_customer'}.contains(o.delivery!.status)) ...[
                const SizedBox(height: 12),
                _OtpCard(deliveryId: o.delivery!.id),
              ],
            ],
            const SectionTitle('تفاصيل الطلب'),
            _ItemsCard(order: o),
            const SectionTitle('عنوان التوصيل'),
            Card(child: ListTile(leading: const Icon(Icons.location_on_outlined), title: Text(o.addressText))),
            if (o.status == 'pending') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('إلغاء الطلب'),
                onPressed: () => _cancel(context, ref),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الطلب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('نعم، إلغاء')),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      await runWithFeedback(context, () => ref.read(ordersRepositoryProvider).cancelOrder(orderId), success: 'تم إلغاء الطلب');
    }
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});

  final OrderDetails order;

  static const _steps = ['pending', 'accepted', 'preparing', 'ready_for_pickup', 'on_the_way', 'delivered'];

  @override
  Widget build(BuildContext context) {
    final status = order.status == 'picked_up' ? 'on_the_way' : order.status;
    final current = _steps.indexOf(status);
    final failed = order.status == 'cancelled' || order.status == 'rejected';
    final color = orderStatusColor(order.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(failed ? Icons.cancel : (order.status == 'delivered' ? Icons.check_circle : Icons.timelapse), color: color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(orderStatusLabels[order.status] ?? order.status,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
                  Text(order.store.name),
                ]),
              ),
            ]),
            if (failed && order.cancellationReason != null) ...[
              const SizedBox(height: 8),
              Text('السبب: ${order.cancellationReason}'),
            ],
            if (!failed) ...[
              const SizedBox(height: 16),
              Row(children: [
                for (var i = 0; i < _steps.length; i++)
                  Expanded(
                    child: Container(
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= current ? color : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveMap extends ConsumerWidget {
  const _LiveMap({required this.order});

  final OrderDetails order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = order.delivery!;
    final live = ref.watch(driverPositionProvider(d.id)).value;
    final driverLat = live?.latitude ?? d.driverLatitude;
    final driverLng = live?.longitude ?? d.driverLongitude;
    final heading = live?.heading ?? d.driverHeading;
    final destination = LatLng(order.deliveryLatitude, order.deliveryLongitude);
    final store = order.store.latitude == null ? null : LatLng(order.store.latitude!, order.store.longitude!);
    final driver = driverLat == null ? null : LatLng(driverLat, driverLng!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 240,
        child: AppMap(
          center: driver ?? store ?? destination,
          zoom: 14,
          pins: [
            if (store != null) MapPin(point: store, icon: Icons.storefront, color: Colors.deepOrange),
            MapPin(point: destination, icon: Icons.home, color: Colors.green),
            if (driver != null) MapPin(point: driver, icon: Icons.navigation, color: Colors.blue, rotation: heading),
          ],
          polyline: [
            ?driver,
            if (store != null && {'assigned', 'accepted', 'arrived_at_store'}.contains(d.status)) store,
            destination,
          ],
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.delivery});

  final DeliveryInfo delivery;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
        title: Text(delivery.driverName),
        subtitle: Text([deliveryStatusLabels[delivery.status], delivery.vehiclePlate].whereType<String>().join(' • ')),
        trailing: delivery.driverPhone == null
            ? null
            : IconButton(
                icon: const Icon(Icons.phone),
                tooltip: delivery.driverPhone,
                onPressed: () => callPhone(delivery.driverPhone!),
              ),
      ),
    );
  }
}

/// رمز التسليم: العميل يعرضه، والسائق يدخله في تطبيقه لتأكيد التسليم
class _OtpCard extends ConsumerStatefulWidget {
  const _OtpCard({required this.deliveryId});

  final String deliveryId;

  @override
  ConsumerState<_OtpCard> createState() => _OtpCardState();
}

class _OtpCardState extends ConsumerState<_OtpCard> {
  String? _code;
  bool _busy = false;

  Future<void> _generate() async {
    setState(() => _busy = true);
    await runWithFeedback(context, () async {
      final code = await ref.read(ordersRepositoryProvider).issueDeliveryOtp(widget.deliveryId);
      if (mounted) setState(() => _code = code);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text('رمز تأكيد الاستلام', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('أعطِ هذا الرمز للسائق عند استلامك الطلب فقط', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          if (_code != null)
            Text(_code!.split('').join('  '),
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4), textDirection: TextDirection.ltr),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _generate,
            child: Text(_code == null ? 'إظهار الرمز' : 'رمز جديد'),
          ),
        ]),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final OrderDetails order;

  @override
  Widget build(BuildContext context) {
    Widget row(String l, double v, {bool bold = false, bool negative = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.bold : null))),
            Text('${negative ? '- ' : ''}${money(v)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final i in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i.quantity}×  ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.name),
                      if (i.notes != null) Text(i.notes!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                  ),
                  Text(money(i.lineTotal)),
                ]),
              ),
            const Divider(),
            row('المنتجات', order.subtotal),
            row('التوصيل', order.deliveryFee),
            if (order.serviceFee > 0) row('رسوم الخدمة', order.serviceFee),
            if (order.tax > 0) row('الضريبة', order.tax),
            if (order.discount > 0) row('الخصم', order.discount, negative: true),
            const Divider(),
            row('الإجمالي', order.total, bold: true),
            const SizedBox(height: 4),
            Text(paymentMethodLabels[order.paymentMethod] ?? order.paymentMethod, style: const TextStyle(color: Colors.grey)),
            if (order.notes != null) ...[
              const SizedBox(height: 8),
              Text('ملاحظات: ${order.notes}'),
            ],
          ],
        ),
      ),
    );
  }
}
