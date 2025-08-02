import 'package:shared_preferences/shared_preferences.dart';

class RfidSettingsStorage {
  static const _keyPort = 'rfid_port';
  static const _keyBaud = 'rfid_baud';
  static const _keyTimeout = 'rfid_timeout';
  static const _keyDeviceAddr = 'rfid_device_address';
  static const _keyStartFreq = 'rfid_start_freq';
  static const _keyEndFreq = 'rfid_end_freq';
  static const _keySingleFreq = 'rfid_single_freq';
  static const _keyRegion = 'rfid_region';
  static const _keyInterface = 'rfid_interface';
  static const _keyAutoConnect = 'rfid_auto_connect';
  static const _keyContinuous = 'rfid_continuous';
  static const _keyBeepOnRead = 'rfid_beep_on_read';
  static const _keyPower = 'rfid_power';

  Future<void> save(Map<String, dynamic> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyPort, m['port'] as String);
    await p.setInt(_keyBaud, m['baud'] as int);
    await p.setInt(_keyTimeout, m['timeout'] as int);
    await p.setString(_keyDeviceAddr, m['deviceAddress'] as String);
    await p.setDouble(_keyStartFreq, m['startFreq'] as double);
    await p.setDouble(_keyEndFreq, m['endFreq'] as double);
    await p.setBool(_keySingleFreq, m['singleFreq'] as bool);
    await p.setString(_keyRegion, m['region'] as String);
    await p.setString(_keyInterface, m['interface'] as String);
    await p.setBool(_keyAutoConnect, m['autoConnect'] as bool);
    await p.setBool(_keyContinuous, m['continuous'] as bool);
    await p.setBool(_keyBeepOnRead, m['beepOnRead'] as bool);
    await p.setInt(_keyPower, m['power'] as int);
  }

  Future<Map<String, dynamic>> load() async {
    final p = await SharedPreferences.getInstance();
    return {
      'port': p.getString(_keyPort) ?? 'COM3',
      'baud': p.getInt(_keyBaud) ?? 115200,
      'timeout': p.getInt(_keyTimeout) ?? 5000,
      'deviceAddress': p.getString(_keyDeviceAddr) ?? '0',
      'startFreq': p.getDouble(_keyStartFreq) ?? 920.125,
      'endFreq': p.getDouble(_keyEndFreq) ?? 924.875,
      'singleFreq': p.getBool(_keySingleFreq) ?? false,
      'region': p.getString(_keyRegion) ?? 'China_1',
      'interface': p.getString(_keyInterface) ?? 'USB',
      'autoConnect': p.getBool(_keyAutoConnect) ?? true,
      'continuous': p.getBool(_keyContinuous) ?? false,
      'beepOnRead': p.getBool(_keyBeepOnRead) ?? true,
      'power': p.getInt(_keyPower) ?? 20,
    };
  }
}
