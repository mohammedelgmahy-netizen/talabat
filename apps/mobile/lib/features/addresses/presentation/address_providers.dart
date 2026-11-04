import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/address_repository_impl.dart';
import '../domain/address.dart';
import '../domain/address_repository.dart';

final addressRepositoryProvider = Provider<AddressRepository>((ref) => SupabaseAddressRepository(ref.watch(supabaseProvider)));

final addressesProvider = FutureProvider<List<Address>>((ref) => ref.watch(addressRepositoryProvider).myAddresses());

/// العنوان المختار حالياً للتوصيل (الافتراضي لو المستخدم ما اختارش)
class SelectedAddressNotifier extends Notifier<Address?> {
  @override
  Address? build() {
    final list = ref.watch(addressesProvider).value;
    if (list == null || list.isEmpty) return null;
    return list.firstWhere((a) => a.isDefault, orElse: () => list.first);
  }

  void select(Address a) => state = a;
}

final selectedAddressProvider = NotifierProvider<SelectedAddressNotifier, Address?>(SelectedAddressNotifier.new);
