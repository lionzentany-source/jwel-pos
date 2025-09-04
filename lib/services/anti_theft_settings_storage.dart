import 'package:shared_preferences/shared_preferences.dart';

class AntiTheftSettingsStorage {
  static const _kEnabled = 'anti_theft_enabled';
  static const _kAutoConnect = 'anti_theft_auto_connect';
  static const _kContinuous = 'anti_theft_continuous';
  static const _kPort = 'anti_theft_port';
  static const _kInterface = 'anti_theft_interface';
  static const _kCooldownSec = 'anti_theft_cooldown_sec';
  static const _kUseAssigned = 'anti_theft_use_assigned_gate';
  static const _kSuppressDuringCashier = 'anti_theft_suppress_during_cashier';

  Future<Map<String, dynamic>> load() async {
    final sp = await SharedPreferences.getInstance();
    return {
      'enabled': sp.getBool(_kEnabled) ?? false,
      'autoConnect': sp.getBool(_kAutoConnect) ?? true,
      'continuous': sp.getBool(_kContinuous) ?? true,
      'port': sp.getString(_kPort) ?? 'COM4',
      'interface': sp.getString(_kInterface) ?? 'USB',
      'cooldownSec': sp.getInt(_kCooldownSec) ?? 15,
      'useAssigned': sp.getBool(_kUseAssigned) ?? true,
      'suppressDuringCashier': sp.getBool(_kSuppressDuringCashier) ?? false,
    };
  }

  Future<void> save(Map<String, dynamic> data) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kEnabled, data['enabled'] as bool);
    await sp.setBool(_kAutoConnect, data['autoConnect'] as bool);
    await sp.setBool(_kContinuous, data['continuous'] as bool);
    await sp.setString(_kPort, data['port'] as String);
    await sp.setString(_kInterface, data['interface'] as String);
    await sp.setInt(_kCooldownSec, data['cooldownSec'] as int);
    await sp.setBool(_kUseAssigned, (data['useAssigned'] as bool?) ?? true);
    await sp.setBool(
      _kSuppressDuringCashier,
      (data['suppressDuringCashier'] as bool?) ?? false,
    );
  }
}
