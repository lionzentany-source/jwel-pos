import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';

abstract class BaseRepository<T> {
  final DatabaseService _databaseService;
  final String tableName;

  BaseRepository(this._databaseService, this.tableName);

  Future<Database> get database async => await _databaseService.database;

  T fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap(T obj);

  Future<int> insert(T obj) async { // Changed return type to int
    final db = await database;
    return await db.insert(tableName, toMap(obj)); // Return the id
  }

  Future<List<T>> getAll() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<T?> getById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> update(T obj) async {
    final db = await database;
    return await db.update(
      tableName,
      toMap(obj),
      where: 'id = ?',
      whereArgs: [toMap(obj)['id']],
    );
  }

  Future<int> delete(int id) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> query({
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      tableName,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<R> transaction<R>(Future<R> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }
}
