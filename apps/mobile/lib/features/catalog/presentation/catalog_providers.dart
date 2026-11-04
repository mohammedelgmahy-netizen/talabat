import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../core/service_area.dart';
import '../../addresses/presentation/address_providers.dart';
import '../data/catalog_repository_impl.dart';
import '../domain/catalog_repository.dart';
import '../domain/entities.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) => SupabaseCatalogRepository(ref.watch(supabaseProvider)));

/// نقطة البحث عن المتاجر: العنوان المختار، وإلا موقع GPS لو جوه منطقة الشغل، وإلا وسط منطقة الشغل
final browsingLocationProvider = FutureProvider<LatLng>((ref) async {
  final address = ref.watch(selectedAddressProvider);
  if (address != null) return LatLng(address.latitude, address.longitude);
  final area = await ref.watch(serviceAreaProvider.future);
  try {
    final me = await ref.read(locationServiceProvider).current();
    return area.contains(me) ? me : area.center;
  } catch (_) {
    return area.center;
  }
});

class StoreSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String q) => state = q;
}

final storeSearchProvider = NotifierProvider<StoreSearchQuery, String>(StoreSearchQuery.new);

final nearbyStoresProvider = FutureProvider.autoDispose<List<Store>>((ref) async {
  final location = await ref.watch(browsingLocationProvider.future);
  final search = ref.watch(storeSearchProvider);
  return ref.watch(catalogRepositoryProvider).nearbyStores(
        latitude: location.latitude,
        longitude: location.longitude,
        search: search,
      );
});

final storeMenuProvider = FutureProvider.autoDispose.family<StoreMenu, String>(
  (ref, storeId) => ref.watch(catalogRepositoryProvider).storeMenu(storeId),
);
