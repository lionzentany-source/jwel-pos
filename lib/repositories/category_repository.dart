import '../models/category.dart';
import 'base_repository.dart';
import '../services/database_service.dart';

class CategoryRepository extends BaseRepository<Category> { // Specify type argument
  CategoryRepository({DatabaseService? databaseService})
      : super(databaseService ?? DatabaseService(), 'categories'); // Pass tableName to super

  // Implement fromMap and toMap
  @override
  Category fromMap(Map<String, dynamic> map) {
    return Category.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(Category obj) {
    return obj.toMap();
  }

  Future<List<Category>> getAllCategories() async {
    final maps = await super.query(orderBy: 'name_ar ASC'); // Use super.query and remove tableName
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<Category?> getCategoryById(int id) async {
    return await super.getById(id); // Use super.getById
  }

  Future<int> insertCategory(Category category) async {
    return await super.insert(category); // Use super.insert
  }

  Future<int> updateCategory(Category category) async {
    return await super.update(category); // Use super.update
  }

  Future<int> deleteCategory(int id) async {
    // التحقق من عدم وجود أصناف مرتبطة بهذه الفئة
    final itemsCountMaps = await super.query( // Use super.query
      columns: ['COUNT(*) as count'],
      where: 'category_id = ?',
      whereArgs: [id],
    );

    if (itemsCountMaps.isNotEmpty && itemsCountMaps.first['count'] as int > 0) {
      throw Exception('لا يمكن حذف الفئة لوجود أصناف مرتبطة بها');
    }

    return await super.delete(id); // Use super.delete
  }

  Future<bool> categoryExists(String nameAr) async {
    final maps = await super.query( // Use super.query
      where: 'name_ar = ?',
      whereArgs: [nameAr],
      limit: 1,
    );
    return maps.isNotEmpty;
  }
}
