import '../models/customer.dart';
import 'base_repository.dart';
import '../services/database_service.dart';

class CustomerRepository extends BaseRepository {
  CustomerRepository({DatabaseService? databaseService}) : super(databaseService ?? DatabaseService());
  static const String tableName = 'customers';

  Future<List<Customer>> getAllCustomers() async {
    final maps = await query(tableName, orderBy: 'name ASC');
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final maps = await query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Customer.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final maps = await this.query(
      tableName,
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Customer?> getCustomerByPhone(String phone) async {
    final maps = await query(
      tableName,
      where: 'phone = ?',
      whereArgs: [phone],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Customer.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertCustomer(Customer customer) async {
    return await insert(tableName, customer.toMap());
  }

  Future<int> updateCustomer(Customer customer) async {
    return await update(
      tableName,
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    // التحقق من عدم وجود فواتير مرتبطة بهذا العميل
    final invoicesCount = await rawQuery(
      'SELECT COUNT(*) as count FROM invoices WHERE customer_id = ?',
      [id],
    );
    
    if (invoicesCount.first['count'] as int > 0) {
      throw Exception('لا يمكن حذف العميل لوجود فواتير مرتبطة به');
    }
    
    return await delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> phoneExists(String phone) async {
    final maps = await query(
      tableName,
      where: 'phone = ?',
      whereArgs: [phone],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<List<Customer>> getRecentCustomers({int limit = 10}) async {
    final maps = await query(
      tableName,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>> getCustomerStats(int customerId) async {
    final result = await rawQuery('''
      SELECT 
        COUNT(*) as total_purchases,
        SUM(total) as total_spent,
        MAX(created_at) as last_purchase
      FROM invoices 
      WHERE customer_id = ?
    ''', [customerId]);

    final row = result.first;
    return {
      'totalPurchases': row['total_purchases'] ?? 0,
      'totalSpent': row['total_spent'] ?? 0.0,
      'lastPurchase': row['last_purchase'],
    };
  }
}
