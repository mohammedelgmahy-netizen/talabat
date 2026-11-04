import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/common.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/store_owner.dart';
import 'store_owner_providers.dart';

/// شاشة استقبال الطلبات لصاحب المتجر (تشبه جهاز الطلبات في المطاعم)
class StoreOrdersPage extends ConsumerStatefulWidget {
  const StoreOrdersPage({super.key});

  @override
  ConsumerState<StoreOrdersPage> createState() => _StoreOrdersPageState();
}

class _StoreOrdersPageState extends ConsumerState<StoreOrdersPage> {
  String? _storeId;

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(myStoresProvider);
    return stores.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(body: ErrorView(error: e, onRetry: () => ref.invalidate(myStoresProvider))),
      data: (list) {
        if (list.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('طلبات المتجر'), actions: [_logout()]),
            body: const EmptyView(icon: Icons.add_business, message: 'أضف متجرك من لوحة التحكم على الويب أولاً'),
          );
        }
        final store = list.firstWhere((s) => s.id == _storeId, orElse: () => list.first);
        return Scaffold(
          appBar: AppBar(
            title: list.length == 1
                ? Text(store.name)
                : DropdownButton<String>(
                    value: store.id,
                    underline: const SizedBox(),
                    items: [for (final s in list) DropdownMenuItem(value: s.id, child: Text(s.name))],
                    onChanged: (v) => setState(() => _storeId = v),
                  ),
            actions: [_logout()],
          ),
          body: Column(children: [
            _OpenSwitch(store: store),
            Expanded(child: _OrdersList(storeId: store.id)),
          ]),
        );
      },
    );
  }

  Widget _logout() => IconButton(icon: const Icon(Icons.logout), onPressed: () => ref.read(sessionProvider).signOut());
}

class _OpenSwitch extends ConsumerWidget {
  const _OpenSwitch({required this.store});

  final OwnedStore store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (store.status != 'active') {
      return MaterialBanner(
        content: Text(store.status == 'pending_approval' ? 'متجرك في انتظار موافقة الإدارة' : 'المتجر موقوف، تواصل مع الإدارة'),
        leading: const Icon(Icons.info_outline, color: Colors.orange),
        actions: const [SizedBox()],
      );
    }
    return SwitchListTile(
      tileColor: store.isOpen ? Colors.green.shade50 : Colors.red.shade50,
      title: Text(store.isOpen ? 'المتجر مفتوح ويستقبل طلبات' : 'المتجر مغلق', style: const TextStyle(fontWeight: FontWeight.bold)),
      value: store.isOpen,
      onChanged: (v) async {
        final ok = await runWithFeedback(context, () => ref.read(storeOwnerRepositoryProvider).setOpen(store.id, v));
        if (ok) ref.invalidate(myStoresProvider);
      },
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(storeOrdersProvider(storeId));
    return orders.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(storeOrdersProvider(storeId))),
      data: (list) => list.isEmpty
          ? const EmptyView(icon: Icons.receipt_long, message: 'لا توجد طلبات نشطة')
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) => _StoreOrderCard(order: list[i]),
            ),
    );
  }
}

class _StoreOrderCard extends ConsumerWidget {
  const _StoreOrderCard({required this.order});

  final StoreOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(storeOwnerRepositoryProvider);
    Future<void> set(String status, {String? reason}) =>
        runWithFeedback(context, () => repo.updateOrderStatus(order.id, status, reason: reason));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: order.status == 'pending' ? const BorderSide(color: Colors.orange, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('#${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(width: 8),
              Text(timeOf(order.placedAt), style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              StatusChip(status: order.status),
            ]),
            const Divider(),
            for (final (qty, name, notes) in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('$qty × $name${notes != null ? '  ($notes)' : ''}', style: const TextStyle(fontSize: 15)),
              ),
            if (order.notes != null) ...[
              const SizedBox(height: 6),
              Text('ملاحظة العميل: ${order.notes}', style: const TextStyle(color: Colors.deepOrange)),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Text(money(order.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(paymentMethodLabels[order.paymentMethod] ?? '', style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              if (order.status != 'pending')
                order.hasDriver
                    ? Text('🛵 ${deliveryStatusLabels[order.driverStatus] ?? ''}', style: const TextStyle(fontSize: 12))
                    : TextButton.icon(
                        icon: const Icon(Icons.person_search, size: 18),
                        label: const Text('ابحث عن سائق'),
                        onPressed: () => runWithFeedback(context, () async {
                          final id = await repo.assignDriver(order.id);
                          if (id == null) throw AppException('لا يوجد سائق متاح قريب حالياً، حاول بعد قليل');
                        }, success: 'تم إسناد سائق'),
                      ),
            ]),
            const SizedBox(height: 8),
            _actions(context, set),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, Future<void> Function(String, {String? reason}) set) {
    switch (order.status) {
      case 'pending':
        return Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                final reason = await _askReason(context);
                if (reason != null) await set('rejected', reason: reason);
              },
              child: const Text('رفض'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: FilledButton(onPressed: () => set('accepted'), child: const Text('قبول'))),
        ]);
      case 'accepted':
        return FilledButton(onPressed: () => set('preparing'), child: const Text('بدء التحضير'));
      case 'preparing':
        return FilledButton(onPressed: () => set('ready_for_pickup'), child: const Text('جاهز للاستلام'));
      case 'ready_for_pickup':
        return const Text('في انتظار السائق لاستلام الطلب', style: TextStyle(color: Colors.indigo));
      default:
        return const SizedBox.shrink();
    }
  }

  Future<String?> _askReason(BuildContext context) {
    const reasons = ['منتج غير متوفر', 'المتجر مشغول جداً', 'خارج أوقات العمل'];
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('سبب الرفض', style: TextStyle(fontWeight: FontWeight.bold))),
          for (final r in reasons) ListTile(title: Text(r), onTap: () => Navigator.pop(context, r)),
        ]),
      ),
    );
  }
}
