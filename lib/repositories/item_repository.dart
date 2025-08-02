import '../models/item.dart';
import 'base_repository.dart';

import '../services/database_service.dart';

class ItemRepository extends BaseRepository {
  ItemRepository({DatabaseService? databaseService}) : super(databaseService ?? DatabaseService());
  static const String tableName = 'items';

  Future<List<Item>> getAllItems() async {
    final maps = await query(tableName, orderBy: 'created_at DESC');
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<List<Item>> getItemsByStatus(ItemStatus status) async {
    final maps = await query(
      tableName,
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<List<Item>> getItemsByCategory(int categoryId) async {
    final maps = await query(
      tableName,
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<Item?> getItemById(int id) async {
    final maps = await query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Item.fromMap(maps.first);
    }
    return null;
  }

  Future<Item?> getItemByRfidTag(String rfidTag) async {
    final maps = await query(
      tableName,
      where: 'rfid_tag = ?',
      whereArgs: [rfidTag],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Item.fromMap(maps.first);
    }
    return null;
  }

  Future<Item?> getItemBySku(String sku) async {
    final maps = await query(
      tableName,
      where: 'sku = ?',
      whereArgs: [sku],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Item.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertItem(Item item) async {
    return await insert(tableName, item.toMap());
  }

  Future<int> updateItem(Item item) async {
    return await update(
      tableName,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    // التحقق من عدم وجود فواتير مرتبطة بهذا الصنف
    final invoiceItemsCount = await rawQuery(
      'SELECT COUNT(*) as count FROM invoice_items WHERE item_id = ?',
      [id],
    );
    
    if (invoiceItemsCount.first['count'] as int > 0) {
      throw Exception('لا يمكن حذف الصنف لوجود فواتير مرتبطة به');
    }
    
    return await delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> skuExists(String sku) async {
    final maps = await query(
      tableName,
      where: 'sku = ?',
      whereArgs: [sku],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<bool> rfidTagExists(String rfidTag) async {
    final maps = await query(
      tableName,
      where: 'rfid_tag = ?',
      whereArgs: [rfidTag],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<int> linkRfidTag(int itemId, String rfidTag) async {
    // التحقق من عدم استخدام البطاقة مسبقاً
    if (await rfidTagExists(rfidTag)) {
      throw Exception('هذه البطاقة مستخدمة مسبقاً');
    }
    
    return await update(
      tableName,
      {
        'rfid_tag': rfidTag,
        'status': ItemStatus.inStock.name,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<String> generateNextSku() async {
    final result = await rawQuery(
      'SELECT COUNT(*) as count FROM $tableName',
    );
    final count = result.first['count'] as int;
    return 'JWE${(count + 1).toString().padLeft(6, '0')}';
  }

  // إحصائيات المخزون
  Future<Map<String, int>> getInventoryStats() async {
    final result = await rawQuery('''
      SELECT 
        status,
        COUNT(*) as count
      FROM $tableName 
      GROUP BY status
    ''');
    
    Map<String, int> stats = {};
    for (var row in result) {
      stats[row['status'] as String] = row['count'] as int;
    }
    
    return stats;
  }
}
