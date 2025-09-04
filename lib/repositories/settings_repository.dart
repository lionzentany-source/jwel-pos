import '../services/database_service.dart';
import 'dart:convert';
import '../models/printer_settings.dart';

class SettingsRepository {
  // مفاتيح شائعة الاستخدام
  static const String kRequireAdminPasswordSetup =
      'require_admin_password_setup';

  // حفظ اسم الطابعة الافتراضية
  Future<void> setDefaultPrinterName(String printerName) async {
    await _setSetting('default_printer_name', printerName);
  }

  // جلب اسم الطابعة الافتراضية
  Future<String?> getDefaultPrinterName() async {
    return await _getSetting('default_printer_name');
  }

  final DatabaseService _databaseService;

  SettingsRepository({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService();

  Future<String?> _getSetting(String key) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first['value'] as String?;
    }
    return null;
  }

  Future<int> _setSetting(String key, String value) async {
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();

    // محاولة التحديث أولاً
    final updateCount = await db.update(
      'settings',
      {'value': value, 'updated_at': now},
      where: 'key = ?',
      whereArgs: [key],
    );

    // إذا لم يتم التحديث، قم بالإدراج
    if (updateCount == 0) {
      return await db.insert('settings', {
        'key': key,
        'value': value,
        'updated_at': now,
      });
    }

    return updateCount;
  }

  // Getters
  Future<double?> getTaxRate() async {
    final value = await _getSetting('tax_rate');
    return value != null ? double.tryParse(value) : null;
  }

  Future<double?> getGoldPrice() async {
    // Deprecated: kept for backward compatibility if called before migration cleanup
    return null;
  }

  Future<double?> getSilverPrice() async {
    // Deprecated
    return null;
  }

  Future<String?> getStoreName() async {
    return await _getSetting('store_name');
  }

  Future<String?> getStoreAddress() async {
    return await _getSetting('store_address');
  }

  Future<String?> getStorePhone() async {
    return await _getSetting('store_phone');
  }

  Future<String?> getInvoiceFooter() async {
    return await _getSetting('invoice_footer');
  }

  Future<String?> getCurrency() async {
    return await _getSetting('currency');
  }

  // Setters
  Future<int> setGoldPrice(double price) async {
    // Deprecated no-op
    return 0;
  }

  Future<int> setSilverPrice(double price) async {
    // Deprecated no-op
    return 0;
  }

  Future<int> setStoreName(String name) async {
    return await _setSetting('store_name', name);
  }

  Future<int> setStoreAddress(String address) async {
    return await _setSetting('store_address', address);
  }

  Future<int> setStorePhone(String phone) async {
    return await _setSetting('store_phone', phone);
  }

  Future<int> setInvoiceFooter(String footer) async {
    return await _setSetting('invoice_footer', footer);
  }

  Future<int> setTaxRate(double rate) async {
    return await _setSetting('tax_rate', rate.toString());
  }

  Future<int> setCurrency(String currency) async {
    return await _setSetting('currency', currency);
  }

  // Printer settings persistence
  Future<int> setDefaultPrinterSettings(PrinterSettings settings) async {
    final jsonStr = jsonEncode(settings.toMap());
    return await _setSetting('default_printer_settings', jsonStr);
  }

  Future<PrinterSettings?> getDefaultPrinterSettings() async {
    final value = await _getSetting('default_printer_settings');
    if (value == null) return null;
    try {
      final map = jsonDecode(value) as Map<String, dynamic>;
      return PrinterSettings.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  // Flags & simple settings helpers
  Future<bool> getBoolFlag(String key, {bool defaultValue = false}) async {
    final v = await _getSetting(key);
    if (v == null) return defaultValue;
    return v.toLowerCase() == 'true' || v == '1';
  }

  Future<void> setBoolFlag(String key, bool value) async {
    await _setSetting(key, value ? 'true' : 'false');
  }

  // Convenience helpers for specific flags
  Future<bool> getPosKeyboardWedgeEnabled() async {
    return await getBoolFlag('pos_keyboard_wedge_enabled', defaultValue: true);
  }

  Future<void> setPosKeyboardWedgeEnabled(bool enabled) async {
    await setBoolFlag('pos_keyboard_wedge_enabled', enabled);
  }
}
