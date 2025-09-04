import '../models/expense.dart';
import 'base_repository.dart';
import '../services/database_service.dart';

class ExpenseRepository extends BaseRepository<Expense> {
  ExpenseRepository({DatabaseService? databaseService})
    : super(databaseService ?? DatabaseService(), 'expenses');

  @override
  Expense fromMap(Map<String, dynamic> map) => Expense.fromMap(map);

  @override
  Map<String, dynamic> toMap(Expense obj) => obj.toMap();

  Future<List<Expense>> getExpensesByDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final maps = await super.query(
      where: 'date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map(fromMap).toList();
  }

  Future<double> sumExpensesByDateRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database; // use BaseRepository provided database getter
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE date BETWEEN ? AND ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
