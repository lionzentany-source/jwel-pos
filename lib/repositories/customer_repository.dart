import '../models/customer.dart';
import 'base_repository.dart';
import '../services/database_service.dart';

class CustomerRepository extends BaseRepository<Customer> {
  CustomerRepository({DatabaseService? databaseService})
      : super(databaseService ?? DatabaseService(), 'customers');

  @override
  Customer fromMap(Map<String, dynamic> map) {
    return Customer.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(Customer obj) {
    return obj.toMap();
  }

  Future<List<Customer>> getAllCustomers() async {
    final maps = await super.query(orderBy: 'name ASC');
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    return await super.getById(id);
  }

  Future<int> insertCustomer(Customer customer) async {
    return await super.insert(customer);
  }

  Future<int> updateCustomer(Customer customer) async {
    return await super.update(customer);
  }

  Future<int> deleteCustomer(int id) async {
    return await super.delete(id);
  }

  Future<bool> customerExists(String name) async {
    final maps = await super.query(
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return maps.isNotEmpty;
  }
}
