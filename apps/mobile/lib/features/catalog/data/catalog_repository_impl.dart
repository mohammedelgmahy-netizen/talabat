import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/catalog_repository.dart';
import '../domain/entities.dart';

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Store>> nearbyStores({required double latitude, required double longitude, String? search}) =>
      guard(() async {
        final rows = await _client.rpc('nearby_stores', params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_search': (search == null || search.trim().isEmpty) ? null : search.trim(),
          'p_limit': 50,
          'p_offset': 0,
        }) as List<dynamic>;
        return rows.map((e) => Store.fromJson(e as Map<String, dynamic>)).toList();
      });

  @override
  Future<StoreMenu> storeMenu(String storeId) => guard(() async {
        final results = await Future.wait([
          _client.from('categories').select('id, name, sort_order').eq('store_id', storeId).eq('is_active', true).order('sort_order'),
          _client
              .from('products')
              .select('id, store_id, category_id, name, description, image_url, price, discounted_price, status, calories')
              .eq('store_id', storeId)
              .inFilter('status', ['active', 'out_of_stock'])
              .order('sort_order'),
        ]);
        return StoreMenu(
          categories: results[0].map(Category.fromJson).toList(),
          products: results[1].map(Product.fromJson).toList(),
        );
      });
}
