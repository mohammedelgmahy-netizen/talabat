import '../../../core/utils/json.dart';

class Address {
  const Address({
    this.id,
    required this.label,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
    this.building,
    this.floor,
    this.apartment,
    this.landmark,
    this.isDefault = false,
  });

  final String? id;
  final String label;
  final String addressLine;
  final String? building;
  final String? floor;
  final String? apartment;
  final String? landmark;
  final double latitude;
  final double longitude;
  final bool isDefault;

  String get labelText => const {'home': 'المنزل', 'work': 'العمل'}[label] ?? label;

  String get fullText => [
        addressLine,
        if (building?.isNotEmpty ?? false) 'عمارة $building',
        if (floor?.isNotEmpty ?? false) 'دور $floor',
        if (apartment?.isNotEmpty ?? false) 'شقة $apartment',
      ].join('، ');

  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: j['id'] as String,
        label: j['label'] as String,
        addressLine: j['address_line'] as String,
        building: j['building'] as String?,
        floor: j['floor'] as String?,
        apartment: j['apartment'] as String?,
        landmark: j['landmark'] as String?,
        latitude: toDouble(j['latitude']),
        longitude: toDouble(j['longitude']),
        isDefault: j['is_default'] == true,
      );
}
