import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/common.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/driver.dart';
import 'driver_providers.dart';

class DriverHomePage extends ConsumerWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(locationReporterProvider); // تشغيل إرسال الموقع في الخلفية
    final profile = ref.watch(driverProfileProvider);
    final tasks = ref.watch(driverTasksProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text('أهلاً ${user.fullName}')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(driverProfileProvider)),
        data: (p) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(driverTasksProvider);
            ref.invalidate(driverSummaryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!p.isVerified)
                const Card(
                  color: Color(0xFFFFF3E0),
                  child: ListTile(
                    leading: Icon(Icons.hourglass_top, color: Colors.orange),
                    title: Text('حسابك في انتظار التوثيق'),
                    subtitle: Text('لن تصلك طلبات حتى توثّق الإدارة حسابك'),
                  ),
                ),
              _AvailabilityCard(profile: p),
              const SizedBox(height: 12),
              const _SummaryRow(),
              const SectionTitle('الشحنات الحالية'),
              ...tasks.when(
                loading: () => [const Padding(padding: EdgeInsets.all(24), child: LoadingView())],
                error: (e, _) => [ErrorView(error: e)],
                data: (list) => list.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: EmptyView(
                            icon: Icons.delivery_dining,
                            message: p.isOnline ? 'في انتظار طلبات قريبة منك...' : 'فعّل الاتصال لاستقبال الطلبات',
                          ),
                        ),
                      ]
                    : [for (final t in list) _TaskCard(task: t)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityCard extends ConsumerWidget {
  const _AvailabilityCard({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = profile.isOnline;
    final busy = profile.availability == 'busy';
    return Card(
      color: online ? Colors.green.shade50 : null,
      child: SwitchListTile(
        value: online,
        onChanged: busy
            ? null
            : (v) => runWithFeedback(
                  context,
                  () => ref.read(driverRepositoryProvider).setAvailability(ref.read(currentUserProvider).id, v ? 'online' : 'offline'),
                ),
        secondary: Icon(online ? Icons.wifi_tethering : Icons.wifi_tethering_off, color: online ? Colors.green : Colors.grey, size: 32),
        title: Text(busy ? 'مشغول بشحنة' : (online ? 'متصل - تستقبل الطلبات' : 'غير متصل'), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('⭐ ${profile.rating.toStringAsFixed(1)} • ${profile.totalDeliveries} توصيلة'),
      ),
    );
  }
}

class _SummaryRow extends ConsumerWidget {
  const _SummaryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(driverSummaryProvider).value;
    Widget tile(String label, String value, IconData icon) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
          ),
        );
    return Row(children: [
      tile('أرباح اليوم', money(s?.todayEarnings ?? 0), Icons.payments_outlined),
      const SizedBox(width: 8),
      tile('توصيلات اليوم', '${s?.todayDeliveries ?? 0}', Icons.check_circle_outline),
      const SizedBox(width: 8),
      tile('كاش معك', money(s?.cashToCollect ?? 0), Icons.account_balance_wallet_outlined),
    ]);
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final DriverTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(driverRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: task.isNew ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: task.isNew ? null : () => context.push('/driver/delivery/${task.orderId}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('طلب #${task.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  StatusChip(status: task.isNew ? 'pending' : 'on_the_way', label: deliveryStatusLabels[task.status]),
                ]),
                const SizedBox(height: 10),
                _line(Icons.storefront, task.storeName, task.storeAddress),
                const SizedBox(height: 6),
                _line(Icons.home_outlined, 'العميل', task.dropoffAddress),
                const SizedBox(height: 10),
                Row(children: [
                  Text('ربحك: ${money(task.earning)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (task.distanceToStoreM != null) Text('${(task.distanceToStoreM! / 1000).toStringAsFixed(1)} كم للمتجر'),
                ]),
                if (task.paymentMethod == 'cash') Text('تحصيل كاش: ${money(task.orderTotal)}', style: const TextStyle(color: Colors.orange)),
                if (task.isNew) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => runWithFeedback(context, () => repo.updateStatus(task.id, 'cancelled', reason: 'رفض السائق')),
                        child: const Text('رفض'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () async {
                          final ok = await runWithFeedback(context, () => repo.updateStatus(task.id, 'accepted'));
                          if (ok && context.mounted) context.push('/driver/delivery/${task.orderId}');
                        },
                        child: const Text('قبول الشحنة'),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String title, String subtitle) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]);
}
