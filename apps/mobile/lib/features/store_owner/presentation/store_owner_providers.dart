import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/store_owner_repository_impl.dart';
import '../domain/store_owner.dart';
import '../domain/store_owner_repository.dart';

final storeOwnerRepositoryProvider = Provider<StoreOwnerRepository>((ref) => SupabaseStoreOwnerRepository(ref.watch(supabaseProvider)));

final myStoresProvider = FutureProvider<List<OwnedStore>>(
  (ref) => ref.watch(storeOwnerRepositoryProvider).myStores(ref.watch(currentUserProvider).id),
);

final storeOrdersProvider = StreamProvider.autoDispose.family<List<StoreOrder>, String>(
  (ref, storeId) => ref.watch(storeOwnerRepositoryProvider).watchActiveOrders(storeId),
);
