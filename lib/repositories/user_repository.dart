import '../models/user.dart';
import 'base_repository.dart';
import '../services/database_service.dart';

class UserRepository extends BaseRepository<User> {
  UserRepository({DatabaseService? databaseService})
      : super(databaseService ?? DatabaseService(), 'users');

  @override
  User fromMap(Map<String, dynamic> map) {
    return User.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(User obj) {
    return obj.toMap();
  }

  Future<User?> getUserByUsername(String username) async {
    final maps = await super.query(
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<User?> getById(int id) async {
    final maps = await super.query(
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final maps = await super.query(orderBy: 'created_at DESC');
    return maps.map((e) => User.fromMap(e)).toList();
  }

  Future<int> insertUser(User user) async {
    return await super.insert(user);
  }

  Future<int> updateUser(User user) async {
    return await super.update(user);
  }

  Future<int> deleteUser(int id) async {
    return await super.delete(id);
  }
}
