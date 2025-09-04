import '../models/material.dart'; // Note: 'material' is a reserved keyword, consider renaming the model
import 'base_repository.dart';
import '../services/database_service.dart';

class MaterialRepository extends BaseRepository<Material> {
  MaterialRepository({DatabaseService? databaseService})
    : super(databaseService ?? DatabaseService(), 'materials');

  @override
  Material fromMap(Map<String, dynamic> map) {
    return Material.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(Material obj) {
    return obj.toMap();
  }

  Future<List<Material>> getAllMaterials() async {
    final maps = await super.query(orderBy: 'name_ar ASC');
    return maps.map((map) => Material.fromMap(map)).toList();
  }

  Future<List<Material>> getVariableMaterials() async {
    final maps = await super.query(
      where: 'is_variable = 1',
      orderBy: 'name_ar ASC',
    );
    return maps.map(Material.fromMap).toList();
  }

  Future<Material?> getMaterialById(int id) async {
    return await super.getById(id);
  }

  Future<int> insertMaterial(Material material) async {
    return await super.insert(material);
  }

  Future<int> updateMaterial(Material material) async {
    return await super.update(material);
  }

  Future<int> updateMaterialPrice(int id, double newPrice) async {
    final db = await database;
    return await db.update(
      'materials',
      {'price_per_gram': newPrice},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMaterial(int id) async {
    // تحقق صارم من عدم وجود أصناف مرتبطة بالمادة قبل الحذف
    final db = await database;
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM items WHERE material_id = ?',
      [id],
    );
    final count = (countResult.first['cnt'] as int?) ?? 0;
    if (count > 0) {
      throw Exception('لا يمكن حذف المادة لوجود $count صنف/أصناف مرتبطة بها');
    }
    return await super.delete(id);
  }

  Future<bool> materialExists(String nameAr) async {
    final maps = await super.query(
      where: 'name_ar = ?',
      whereArgs: [nameAr],
      limit: 1,
    );
    return maps.isNotEmpty;
  }
}
