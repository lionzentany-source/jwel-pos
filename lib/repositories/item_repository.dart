import '../models/item.dart';
import 'base_repository.dart';
import '../services/database_service.dart';

class ItemRepository extends BaseRepository<Item> {
  ItemRepository({DatabaseService? databaseService})
      : super(databaseService ?? DatabaseService(), 'items');

  @override
  Item fromMap(Map<String, dynamic> map) {
    return Item.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(Item obj) {
    return obj.toMap();
  }

  Future<List<Item>> getAllItems() async {
    final maps = await super.query(orderBy: 'sku ASC');
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<Item?> getItemById(int id) async {
    return await super.getById(id);
  }

  Future<int> insertItem(Item item) async {
    return await super.insert(item);
  }

  Future<int> updateItem(Item item) async {
    return await super.update(item);
  }

  Future<int> deleteItem(int id) async {
    return await super.delete(id);
  }

  Future<bool> itemExists(String sku) async {
    final maps = await super.query(
      where: 'sku = ?',
      whereArgs: [sku],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<String> generateNextSku() async {
    final maps = await super.query(orderBy: 'id DESC', limit: 1);
    if (maps.isEmpty) {
      return 'ITEM001';
    }
    
    // البحث عن أكبر رقم SKU
    final allItems = await super.query();
    int maxNumber = 0;
    
    for (final map in allItems) {
      final sku = map['sku'] as String;
      if (sku.startsWith('ITEM')) {
        final numberPart = sku.substring(4);
        final number = int.tryParse(numberPart);
        if (number != null && number > maxNumber) {
          maxNumber = number;
        }
      }
    }
    
    final nextNumber = maxNumber + 1;
    return 'ITEM${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<List<Item>> getItemsByCategoryId(int categoryId) async {
    final maps = await super.query(
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'sku ASC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<List<Item>> getItemsByMaterialId(int materialId) async {
    final maps = await super.query(
      where: 'material_id = ?',
      whereArgs: [materialId],
      orderBy: 'sku ASC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<Item?> getItemByRfidTag(String rfidTag) async {
    final maps = await super.query(
      where: 'rfid_tag = ?',
      whereArgs: [rfidTag],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Item.fromMap(maps.first);
    }
    return null;
  }

  Future<int> linkRfidTag(int itemId, String rfidTag) async {
    // التحقق من عدم وجود البطاقة مع صنف آخر
    final existingItem = await getItemByRfidTag(rfidTag);
    if (existingItem != null && existingItem.id != itemId) {
      throw Exception('هذه البطاقة مربوطة بالفعل بصنف آخر: ${existingItem.sku}');
    }
    
    final item = await getItemById(itemId);
    if (item != null) {
      // إنشاء نسخة جديدة من الصنف مع البطاقة والحالة المحدثة
      final updatedItem = Item(
        id: item.id,
        sku: item.sku,
        categoryId: item.categoryId,
        materialId: item.materialId,
        weightGrams: item.weightGrams,
        karat: item.karat,
        workmanshipFee: item.workmanshipFee,
        stonePrice: item.stonePrice,
        costPrice: item.costPrice,
        imagePath: item.imagePath,
        rfidTag: rfidTag, // ربط البطاقة
        status: ItemStatus.inStock, // تحديث الحالة
        createdAt: item.createdAt,
      );
      return await super.update(updatedItem);
    }
    throw Exception('الصنف غير موجود');
  }

  // Specific item-related methods
  Future<List<Item>> getItemsByStatus(String status) async {
    // Assuming 'status' is a field in the Item model or can be derived
    // This is a placeholder, you'll need to define how 'status' is determined
    final maps = await super.query(
      where: 'status = ?', // You might need to adjust this based on your Item model
      whereArgs: [status],
      orderBy: 'sku ASC',
    );
    return maps.map((map) => Item.fromMap(map)).toList();
  }

  Future<Map<String, int>> getInventoryStats() async {
    // This is a placeholder for inventory statistics.
    // You would typically query the database to get counts of items by status, category, etc.
    // Example: SELECT status, COUNT(*) FROM items GROUP BY status
    final maps = await super.query(
      columns: ['status', 'COUNT(*) as count'],
      groupBy: 'status',
    );
    final stats = <String, int>{};
    for (var map in maps) {
      stats[map['status'] as String] = map['count'] as int;
    }
    return stats;
  }
}
