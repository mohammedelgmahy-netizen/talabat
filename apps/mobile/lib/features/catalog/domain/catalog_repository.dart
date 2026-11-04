import 'entities.dart';

abstract class CatalogRepository {
  Future<List<Store>> nearbyStores({required double latitude, required double longitude, String? search});

  Future<StoreMenu> storeMenu(String storeId);
}
