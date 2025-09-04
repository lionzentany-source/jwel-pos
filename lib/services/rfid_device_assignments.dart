import 'package:shared_preferences/shared_preferences.dart';

enum RfidRole { cashier, gate, inventory }

class RfidDeviceConfig {
  final String interface; // USB | CDC_COM | KeyBoard | BLE
  final String identifier; // COMx or BLE id/name
  final int baudRate;
  const RfidDeviceConfig({
    required this.interface,
    required this.identifier,
    this.baudRate = 115200,
  });

  Map<String, dynamic> toMap() => {
    'interface': interface,
    'identifier': identifier,
    'baudRate': baudRate,
  };

  factory RfidDeviceConfig.fromMap(Map<String, dynamic> m) => RfidDeviceConfig(
    interface: m['interface'] as String,
    identifier: m['identifier'] as String,
    baudRate: (m['baudRate'] as int?) ?? 115200,
  );
}

class RfidDeviceAssignmentsStorage {
  static const _kPrefix = 'rfid_assignment_';

  String _key(RfidRole role) => '$_kPrefix${role.name}';

  Future<void> save(RfidRole role, RfidDeviceConfig cfg) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_key(role), <String>[
      cfg.interface,
      cfg.identifier,
      cfg.baudRate.toString(),
    ]);
  }

  Future<RfidDeviceConfig?> load(RfidRole role) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_key(role));
    if (list == null || list.length < 3) return null;
    return RfidDeviceConfig(
      interface: list[0],
      identifier: list[1],
      baudRate: int.tryParse(list[2]) ?? 115200,
    );
  }

  Future<Map<RfidRole, RfidDeviceConfig>> loadAll() async {
    final map = <RfidRole, RfidDeviceConfig>{};
    for (final role in RfidRole.values) {
      final cfg = await load(role);
      if (cfg != null) map[role] = cfg;
    }
    return map;
  }
}
