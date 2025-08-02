import '../models/settings.dart';
import 'base_repository.dart';
import '../services/database_service.dart';

class SettingsRepository extends BaseRepository {
  SettingsRepository({DatabaseService? databaseService}) : super(databaseService ?? DatabaseService());
  static const String tableName = 'settings';

  Future<String?> getSetting(String key) async {
    final maps = await query(
      tableName,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  Future<double> getDoubleValue(String key, {double defaultValue = 0.0}) async {
    final value = await getSetting(key);
    if (value != null) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  Future<int> getIntValue(String key, {int defaultValue = 0}) async {
    final value = await getSetting(key);
    if (value != null) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  Future<bool> getBoolValue(String key, {bool defaultValue = false}) async {
    final value = await getSetting(key);
    if (value != null) {
      return value.toLowerCase() == 'true';
    }
    return defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    final existing = await getSetting(key);
    final now = DateTime.now().toIso8601String();
    
    if (existing != null) {
      await update(
        tableName,
        {'value': value, 'updated_at': now},
        where: 'key = ?',
        whereArgs: [key],
      );
    } else {
      await insert(tableName, {
        'key': key,
        'value': value,
        'updated_at': now,
      });
    }
  }

  Future<void> setDoubleValue(String key, double value) async {
    await setSetting(key, value.toString());
  }

  Future<void> setIntValue(String key, int value) async {
    await setSetting(key, value.toString());
  }

  Future<void> setBoolValue(String key, bool value) async {
    await setSetting(key, value.toString());
  }

  Future<List<Settings>> getAllSettings() async {
    final maps = await query(tableName, orderBy: 'key ASC');
    return maps.map((map) => Settings.fromMap(map)).toList();
  }

  Future<int> deleteSetting(String key) async {
    return await delete(tableName, where: 'key = ?', whereArgs: [key]);
  }

  // دوال مخصصة للإعدادات الشائعة
  Future<double> getGoldPrice() async {
    return await getDoubleValue(SettingsKeys.goldPricePerGram, defaultValue: 200.0);
  }

  Future<void> setGoldPrice(double price) async {
    await setDoubleValue(SettingsKeys.goldPricePerGram, price);
  }

  Future<double> getSilverPrice() async {
    return await getDoubleValue(SettingsKeys.silverPricePerGram, defaultValue: 5.0);
  }

  Future<void> setSilverPrice(double price) async {
    await setDoubleValue(SettingsKeys.silverPricePerGram, price);
  }

  Future<String> getStoreName() async {
    return await getSetting(SettingsKeys.storeName) ?? 'مجوهرات جوهر';
  }

  Future<void> setStoreName(String name) async {
    await setSetting(SettingsKeys.storeName, name);
  }

  Future<String> getCurrency() async {
    return await getSetting(SettingsKeys.currency) ?? 'د.ل';
  }

  Future<void> setCurrency(String currency) async {
    await setSetting(SettingsKeys.currency, currency);
  }

  Future<double> getTaxRate() async {
    return await getDoubleValue(SettingsKeys.taxRate, defaultValue: 0.0);
  }

  Future<void> setTaxRate(double rate) async {
    await setDoubleValue(SettingsKeys.taxRate, rate);
  }
}
