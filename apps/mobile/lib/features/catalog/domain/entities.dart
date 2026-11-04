import '../../../core/utils/json.dart';

class Store {
  const Store({
    required this.id,
    required this.name,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.deliveryFee,
    required this.prepMinutes,
    required this.minOrderAmount,
    required this.rating,
    required this.ratingCount,
    required this.isOpen,
    this.description,
    this.logoUrl,
    this.coverUrl,
  });

  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String addressLine;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final double deliveryFee;
  final int prepMinutes;
  final double minOrderAmount;
  final double rating;
  final int ratingCount;
  final bool isOpen;

  /// الوقت التقريبي = التحضير + القيادة (متوسط 25 كم/س)
  int get etaMinutes => prepMinutes + (distanceKm / 25 * 60).ceil() + 5;

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        logoUrl: j['logo_url'] as String?,
        coverUrl: j['cover_url'] as String?,
        addressLine: (j['address_line'] as String?) ?? '',
        latitude: toDouble(j['latitude']),
        longitude: toDouble(j['longitude']),
        distanceKm: toDouble(j['distance_km']),
        deliveryFee: toDouble(j['delivery_fee']),
        prepMinutes: toInt(j['avg_prep_time_minutes'], 20),
        minOrderAmount: toDouble(j['min_order_amount']),
        rating: toDouble(j['rating']),
        ratingCount: toInt(j['rating_count']),
        isOpen: j['is_open'] == true,
      );
}

class Category {
  const Category({required this.id, required this.name, required this.sortOrder});

  final String id;
  final String name;
  final int sortOrder;

  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(id: j['id'] as String, name: j['name'] as String, sortOrder: toInt(j['sort_order']));
}

class Product {
  const Product({
    required this.id,
    required this.storeId,
    required this.name,
    required this.price,
    required this.status,
    this.categoryId,
    this.description,
    this.imageUrl,
    this.discountedPrice,
    this.calories,
  });

  final String id;
  final String storeId;
  final String? categoryId;
  final String name;
  final String? description;
  final String? imageUrl;
  final double price;
  final double? discountedPrice;
  final String status;
  final int? calories;

  double get effectivePrice => discountedPrice ?? price;
  bool get isAvailable => status == 'active';

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        storeId: j['store_id'] as String,
        categoryId: j['category_id'] as String?,
        name: j['name'] as String,
        description: j['description'] as String?,
        imageUrl: j['image_url'] as String?,
        price: toDouble(j['price']),
        discountedPrice: toDoubleOrNull(j['discounted_price']),
        status: j['status'] as String,
        calories: j['calories'] as int?,
      );
}

class StoreMenu {
  const StoreMenu({required this.categories, required this.products});

  final List<Category> categories;
  final List<Product> products;

  List<Product> productsOf(String? categoryId) => products.where((p) => p.categoryId == categoryId).toList();
}
