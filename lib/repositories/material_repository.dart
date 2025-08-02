import '../models/material.dart';
import 'base_repository.dart';
import '../services/database_service.dart';

class MaterialRepository extends BaseRepository {
  MaterialRepository({DatabaseService? databaseService}) : super(databaseService ?? DatabaseService());
  static const String tableName = 'materials';

  Future<List<Material>> getAllMaterials() async {
    final maps = await query(tableName, orderBy: 'name_ar ASC');
    return maps.map((map) => Material.fromMap(map)).toList();
  }

  Future<Material?> getMaterialById(int id) async {
    final maps = await query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Material.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertMaterial(Material material) async {
    return await insert(tableName, material.toMap());
  }

  Future<int> updateMaterial(Material material) async {
    return await update(
      tableName,
      material.toMap(),
      where: 'id = ?',
      whereArgs: [material.id],
    );
  }

  Future<int> deleteMaterial(int id) async {
    // التحقق من عدم وجود أصناف مرتبطة بهذه المادة
    final itemsCount = await rawQuery(
      'SELECT COUNT(*) as count FROM items WHERE material_id = ?',
      [id],
    );
    
    if (itemsCount.first['count'] as int > 0) {
      throw Exception('لا يمكن حذف المادة لوجود أصناف مرتبطة بها');
    }
    
    return await delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> materialExists(String nameAr) async {
    final maps = await query(
      tableName,
      where: 'name_ar = ?',
      whereArgs: [nameAr],
      limit: 1,
    );
    return maps.isNotEmpty;
  }
}
