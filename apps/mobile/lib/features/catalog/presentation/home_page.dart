import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../addresses/presentation/address_providers.dart';
import '../../cart/presentation/cart_controller.dart';
import '../domain/entities.dart';
import 'catalog_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(selectedAddressProvider);
    final stores = ref.watch(nearbyStoresProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: InkWell(
          onTap: () => context.push('/client/addresses/select'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('التوصيل إلى', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Row(children: [
                Flexible(
                  child: Text(
                    address?.labelText ?? 'موقعي الحالي',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down),
              ]),
            ],
          ),
        ),
      ),
      floatingActionButton: cart.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/client/cart'),
              icon: Badge(label: Text('${cart.count}'), child: const Icon(Icons.shopping_bag_outlined)),
              label: Text(money(cart.subtotal)),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(nearbyStoresProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن مطعم أو منتج'),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), () => ref.read(storeSearchProvider.notifier).set(v));
                  },
                ),
              ),
            ),
            ...stores.when(
              loading: () => [const SliverFillRemaining(child: LoadingView())],
              error: (e, _) => [SliverFillRemaining(child: ErrorView(error: e, onRetry: () => ref.invalidate(nearbyStoresProvider)))],
              data: (list) => list.isEmpty
                  ? [const SliverFillRemaining(child: EmptyView(icon: Icons.storefront, message: 'لا توجد متاجر توصّل لهذا العنوان'))]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        sliver: SliverList.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => StoreCard(store: list[i]),
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class StoreCard extends StatelessWidget {
  const StoreCard({super.key, required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/client/store/${store.id}', extra: store),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: store.coverUrl != null
                      ? Image.network(store.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder(theme))
                      : _placeholder(theme),
                ),
                if (!store.isOpen)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: const Text('مغلق الآن', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: store.logoUrl != null ? NetworkImage(store.logoUrl!) : null,
                    child: store.logoUrl == null ? const Icon(Icons.storefront) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Wrap(spacing: 12, children: [
                          _Meta(icon: Icons.star, text: store.ratingCount == 0 ? 'جديد' : store.rating.toStringAsFixed(1), color: Colors.amber),
                          _Meta(icon: Icons.schedule, text: '${store.etaMinutes} د'),
                          _Meta(icon: Icons.delivery_dining, text: money(store.deliveryFee)),
                          _Meta(icon: Icons.place_outlined, text: km(store.distanceKm)),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
        color: theme.colorScheme.primaryContainer,
        child: Icon(Icons.restaurant, size: 48, color: theme.colorScheme.primary),
      );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color ?? Colors.grey),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12)),
      ]);
}
