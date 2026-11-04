import 'address.dart';

abstract class AddressRepository {
  Future<List<Address>> myAddresses();

  Future<String> save(Address address);

  Future<void> delete(String id);
}
