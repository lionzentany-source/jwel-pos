import '../models/category.dart';
import 'base_repository.dart';
import '../services/database_service.dart';

class CategoryRepository extends BaseRepository {
  CategoryRepository({DatabaseService? databaseService}) : super(databaseService ?? DatabaseService());
  static const String tableName = 'categories';

  Future<List<Category>> getAllCategories() async {
    final maps = await query(tableName, orderBy: 'name_ar ASC');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<Category?> getCategoryById(int id) async {
    final maps = await query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Category.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertCategory(Category category) async {
    return await insert(tableName, category.toMap());
  }

  Future<int> updateCategory(Category category) async {
    return await update(
      tableName,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    // التحقق من عدم وجود أصناف مرتبطة بهذه الفئة
    final itemsCount = await rawQuery(
      'SELECT COUNT(*) as count FROM items WHERE category_id = ?',
      [id],
    );
    
    if (itemsCount.first['count'] as int > 0) {
      throw Exception('لا يمكن حذف الفئة لوجود أصناف مرتبطة بها');
    }
    
    return await delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> categoryExists(String nameAr) async {
    final maps = await query(
      tableName,
      where: 'name_ar = ?',
      whereArgs: [nameAr],
      limit: 1,
    );
    return maps.isNotEmpty;
  }
}
