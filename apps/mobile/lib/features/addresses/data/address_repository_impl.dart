import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/address.dart';
import '../domain/address_repository.dart';

class SupabaseAddressRepository implements AddressRepository {
  SupabaseAddressRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Address>> myAddresses() => guard(() async {
        final rows = await _client.rpc('my_addresses') as List<dynamic>;
        return rows.map((e) => Address.fromJson(e as Map<String, dynamic>)).toList();
      });

  @override
  Future<String> save(Address a) => guard(() async {
        final id = await _client.rpc('save_address', params: {
          'p_id': a.id,
          'p_label': a.label,
          'p_address_line': a.addressLine,
          'p_building': a.building,
          'p_floor': a.floor,
          'p_apartment': a.apartment,
          'p_landmark': a.landmark,
          'p_latitude': a.latitude,
          'p_longitude': a.longitude,
          'p_is_default': a.isDefault,
        });
        return id as String;
      });

  @override
  Future<void> delete(String id) => guard(() => _client.from('user_addresses').delete().eq('id', id));
}
