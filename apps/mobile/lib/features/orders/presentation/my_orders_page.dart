import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/common.dart';
import '../domain/order.dart';
import 'order_providers.dart';

class MyOrdersPage extends ConsumerWidget {
  const MyOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: orders.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(myOrdersProvider)),
        data: (list) {
          if (list.isEmpty) return const EmptyView(icon: Icons.receipt_long, message: 'لم تطلب أي شيء بعد');
          final active = list.where((o) => activeOrderStatuses.contains(o.status)).toList();
          final past = list.where((o) => !activeOrderStatuses.contains(o.status)).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) const SectionTitle('طلبات جارية'),
              for (final o in active) _OrderCard(order: o),
              if (past.isNotEmpty) const SectionTitle('طلبات سابقة'),
              for (final o in past) _OrderCard(order: o),
            ],
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundImage: order.storeLogo != null ? NetworkImage(order.storeLogo!) : null,
            child: order.storeLogo == null ? const Icon(Icons.storefront) : null,
          ),
          title: Text(order.storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('#${order.orderNumber} • ${order.itemsCount} صنف • ${dateTimeOf(order.placedAt)}'),
              const SizedBox(height: 6),
              StatusChip(status: order.status),
            ],
          ),
          trailing: Text(money(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
          onTap: () => context.push('/client/orders/${order.id}'),
        ),
      ),
    );
  }
}
