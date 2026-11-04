import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/labels.dart';
import '../../../core/widgets/common.dart';
import 'driver_providers.dart';

class DriverHistoryPage extends ConsumerWidget {
  const DriverHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(driverSummaryProvider).value;
    final history = ref.watch(driverHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('أرباحي')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(driverHistoryProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _row('هذا الأسبوع', '${money(summary?.weekEarnings ?? 0)} • ${summary?.weekDeliveries ?? 0} توصيلة'),
                  _row('الإجمالي', money(summary?.totalEarnings ?? 0)),
                ]),
              ),
            ),
            const SectionTitle('آخر الشحنات'),
            ...history.when(
              loading: () => [const LoadingView()],
              error: (e, _) => [ErrorView(error: e)],
              data: (list) => list.isEmpty
                  ? [const EmptyView(icon: Icons.history, message: 'لا يوجد سجل بعد')]
                  : [
                      for (final t in list)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('#${t.orderNumber} • ${t.storeName}'),
                            subtitle: Text('${deliveryStatusLabels[t.status]} • ${dateTimeOf(t.assignedAt)}'),
                            trailing: Text(t.status == 'delivered' ? money(t.earning) : '-',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(l)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]),
      );
}
