import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rfid_device_assignments.dart';
import '../services/rfid_service.dart';

final rfidAssignmentsProvider = Provider<RfidDeviceAssignmentsStorage>((ref) {
  return RfidDeviceAssignmentsStorage();
});

/// Returns a connected reader for the given role according to assignment settings.
final rfidReaderForRoleProvider =
    FutureProvider.family<RfidServiceReal, RfidRole>((ref, role) async {
      final assign = ref.read(rfidAssignmentsProvider);
      final cfg = await assign.load(role);
      final r = RfidServiceReal();
      if (cfg == null) {
        // No assignment: leave disconnected, caller may show prompt
        return r;
      }
      if (cfg.interface == 'USB' || cfg.interface == 'CDC_COM') {
        await r.connect(
          port: cfg.identifier,
          baudRate: cfg.baudRate,
          interface: cfg.interface,
        );
      } else if (cfg.interface == 'BLE') {
        await r.connectToBluetoothReader(cfg.identifier);
      } else {
        // Other interfaces can be added here
      }
      return r;
    });
