import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../domain/address.dart';
import 'address_providers.dart';

/// قائمة العناوين. لو اتفتحت بـ selectMode ترجع العنوان المختار
class AddressesPage extends ConsumerWidget {
  const AddressesPage({super.key, this.selectMode = false});

  final bool selectMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    final selected = ref.watch(selectedAddressProvider);
    return Scaffold(
      appBar: AppBar(title: Text(selectMode ? 'التوصيل إلى' : 'عناويني')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/client/addresses/new');
          ref.invalidate(addressesProvider);
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('عنوان جديد'),
      ),
      body: addresses.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(addressesProvider)),
        data: (list) => list.isEmpty
            ? const EmptyView(icon: Icons.location_off, message: 'لا توجد عناوين بعد')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final a = list[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(a.label == 'work' ? Icons.work_outline : Icons.home_outlined),
                      title: Text(a.labelText + (a.isDefault ? ' (الافتراضي)' : '')),
                      subtitle: Text(a.fullText, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: selectMode
                          ? Icon(selected?.id == a.id ? Icons.radio_button_checked : Icons.radio_button_off)
                          : _AddressMenu(address: a),
                      onTap: () {
                        if (selectMode) {
                          ref.read(selectedAddressProvider.notifier).select(a);
                          context.pop();
                        } else {
                          context.push('/client/addresses/edit', extra: a).then((_) => ref.invalidate(addressesProvider));
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AddressMenu extends ConsumerWidget {
  const _AddressMenu({required this.address});

  final Address address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.delete_outline),
      onPressed: () async {
        final ok = await runWithFeedback(context, () => ref.read(addressRepositoryProvider).delete(address.id!), success: 'تم حذف العنوان');
        if (ok) ref.invalidate(addressesProvider);
      },
    );
  }
}
