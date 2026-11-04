import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../cart/presentation/cart_controller.dart';
import '../domain/entities.dart';
import 'catalog_providers.dart';

class StorePage extends ConsumerWidget {
  const StorePage({super.key, required this.store});

  final Store store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(storeMenuProvider(store.id));
    final cart = ref.watch(cartProvider);
    final cartFromThisStore = cart.store?.id == store.id && !cart.isEmpty;

    return Scaffold(
      body: menu.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(storeMenuProvider(store.id))),
        data: (m) {
          // الأقسام اللي فيها منتجات + "أخرى" للمنتجات بدون قسم
          final sections = <(String, List<Product>)>[
            for (final c in m.categories)
              if (m.productsOf(c.id).isNotEmpty) (c.name, m.productsOf(c.id)),
            if (m.productsOf(null).isNotEmpty) ('أخرى', m.productsOf(null)),
          ];
          return DefaultTabController(
            length: sections.length,
            child: NestedScrollView(
              headerSliverBuilder: (_, _) => [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 180,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(store.name),
                    background: store.coverUrl != null
                        ? Image.network(store.coverUrl!, fit: BoxFit.cover, color: Colors.black38, colorBlendMode: BlendMode.darken)
                        : Container(color: Theme.of(context).colorScheme.primary),
                  ),
                  bottom: sections.isEmpty
                      ? null
                      : TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          indicatorColor: Colors.white,
                          tabs: [for (final s in sections) Tab(text: s.$1)],
                        ),
                ),
              ],
              body: sections.isEmpty
                  ? const EmptyView(icon: Icons.no_food, message: 'لا توجد منتجات حالياً')
                  : TabBarView(
                      children: [
                        for (final s in sections)
                          ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: s.$2.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _ProductTile(store: store, product: s.$2[i]),
                          ),
                      ],
                    ),
            ),
          );
        },
      ),
      bottomNavigationBar: cartFromThisStore
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () => context.push('/client/cart'),
                  child: Row(children: [
                    CircleAvatar(radius: 13, backgroundColor: Colors.white24, child: Text('${cart.count}', style: const TextStyle(fontSize: 13, color: Colors.white))),
                    const Expanded(child: Text('عرض السلة', textAlign: TextAlign.center)),
                    Text(money(cart.subtotal)),
                  ]),
                ),
              ),
            )
          : null,
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.store, required this.product});

  final Store store;
  final Product product;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider.notifier);
    if (cart.add(store, product)) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('بدء سلة جديدة؟'),
        content: const Text('سلتك فيها منتجات من متجر آخر. هل تريد مسحها وإضافة هذا المنتج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('سلة جديدة')),
        ],
      ),
    );
    if (replace == true) cart.replaceWith(store, product);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider.select((c) => c.store?.id == store.id ? c.quantityOf(product.id) : 0));
    final canOrder = product.isAvailable && store.isOpen;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (product.description != null) ...[
                    const SizedBox(height: 4),
                    Text(product.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(money(product.effectivePrice), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    if (product.discountedPrice != null) ...[
                      const SizedBox(width: 8),
                      Text(money(product.price), style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 12)),
                    ],
                  ]),
                  if (!product.isAvailable) const Text('غير متوفر حالياً', style: TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 84,
                    child: product.imageUrl != null
                        ? Image.network(product.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFEEEEEE)))
                        : const ColoredBox(color: Color(0xFFEEEEEE), child: Icon(Icons.fastfood, color: Colors.grey)),
                  ),
                ),
                const SizedBox(height: 6),
                if (qty == 0)
                  OutlinedButton(
                    onPressed: canOrder ? () => _add(context, ref) : null,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(84, 34), padding: EdgeInsets.zero),
                    child: const Text('أضف'),
                  )
                else
                  _QtyStepper(
                    qty: qty,
                    onAdd: () => _add(context, ref),
                    onRemove: () => ref.read(cartProvider.notifier).decrement(product.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onAdd, required this.onRemove});

  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(onTap: onRemove, child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.remove, size: 18, color: color))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold))),
        InkWell(onTap: onAdd, child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.add, size: 18, color: color))),
      ]),
    );
  }
}
