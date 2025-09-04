import 'dart:async';
import 'package:flutter/foundation.dart';
import '../repositories/item_repository.dart';
import 'rfid_service.dart';
import 'rfid_session_coordinator.dart';
import 'rfid_device_assignments.dart';

/// Anti-theft gate logic using the real RFID service (no simulator).
/// - Listens to tagStream from RfidServiceReal (a dedicated gate reader connection)
/// - Alarms only for registered items that are not sold
/// - Ignores unregistered tags (no beep)
class AntiTheftService {
  AntiTheftService({RfidServiceReal? gateReader, ItemRepository? itemRepo})
    : _gateReader = gateReader ?? RfidServiceReal(),
      _itemRepo = itemRepo ?? ItemRepository();

  final RfidServiceReal _gateReader;
  final ItemRepository _itemRepo;
  StreamSubscription<String>? _sub;
  final Map<String, DateTime> _cooldown = {};
  Duration cooldown = const Duration(seconds: 15);
  bool suppressDuringCashier = false; // اجعل الكتم أثناء الكاشير اختيارياً

  /// Allow recently sold items to pass without alarm to avoid immediate false alarms at the gate
  Duration saleGrace = const Duration(seconds: 30);
  StreamSubscription<RfidSessionState>? _sessionSub;
  bool _gateAllowed = true;

  /// Connect gate reader (e.g., separate COM port) and optionally start scanning
  Future<void> connectAndStart({
    required String port,
    String interface = 'USB',
    int baudRate = 115200,
    bool continuous = true,
  }) async {
    await _gateReader.connect(
      port: port,
      baudRate: baudRate,
      interface: interface,
    );
    if (_gateReader.currentStatus == RfidReaderStatus.connected && continuous) {
      await _gateReader.startScanning();
    }
    _sub?.cancel();
    _sub = _gateReader.tagStream.listen(_onTag);
    _sessionSub?.cancel();
    // Mark gate desire to be active; coordinator will tell us if allowed now
    RfidSessionCoordinator.instance.setGateDesired(true);
    _gateAllowed = RfidSessionCoordinator.instance.state.gateAllowed;
    _sessionSub = RfidSessionCoordinator.instance.stream.listen((s) {
      _gateAllowed = s.gateAllowed;
    });
  }

  /// Connect using the assigned Gate device from settings, if configured
  Future<void> connectUsingAssignedDevice({bool continuous = true}) async {
    final store = RfidDeviceAssignmentsStorage();
    final cfg = await store.load(RfidRole.gate);
    if (cfg == null) {
      throw StateError('لا يوجد تعيين لجهاز قارئ الباب. الرجاء تعيينه أولاً.');
    }
    if (cfg.interface == 'USB' || cfg.interface == 'CDC_COM') {
      await _gateReader.connect(
        port: cfg.identifier,
        baudRate: cfg.baudRate,
        interface: cfg.interface,
      );
    } else if (cfg.interface == 'BLE') {
      await _gateReader.connectToBluetoothReader(cfg.identifier);
    }
    if (_gateReader.currentStatus == RfidReaderStatus.connected && continuous) {
      await _gateReader.startScanning();
    }
    _sub?.cancel();
    _sub = _gateReader.tagStream.listen(_onTag);
    _sessionSub?.cancel();
    RfidSessionCoordinator.instance.setGateDesired(true);
    _gateAllowed = RfidSessionCoordinator.instance.state.gateAllowed;
    _sessionSub = RfidSessionCoordinator.instance.stream.listen((s) {
      _gateAllowed = s.gateAllowed;
    });
  }

  Future<void> disconnect() async {
    await _gateReader.stopScanning();
    await _gateReader.disconnect();
    await _sub?.cancel();
    _sub = null;
    _sessionSub?.cancel();
    _sessionSub = null;
    RfidSessionCoordinator.instance.setGateDesired(false);
  }

  Future<void> _onTag(String epc) async {
    try {
      if (suppressDuringCashier && !_gateAllowed) {
        debugPrint('🚪 Gate suppressed (cashier active), skipping $epc');
        return;
      }
      // Cooldown per EPC to avoid repeated alarms
      final last = _cooldown[epc];
      final now = DateTime.now();
      if (last != null && now.difference(last) < cooldown) {
        return;
      }

      final item = await _itemRepo.getItemByRfidTag(epc);
      if (item == null) {
        // Unregistered tag: ignore alarm and no beep
        debugPrint('🚪 Gate: ignore unregistered tag $epc');
        return;
      }
      // Optional: If we have a sold timestamp field in the DB, we could check it here.
      // For now, if status is sold we allow, otherwise we alarm.
      if (item.status.name != 'sold') {
        // Registered but not sold => alarm/beep through device speaker if supported
        // Reuse reader beep which we already constrained to registered tags.
        await _gateReader.playBeep();
        _cooldown[epc] = now;
        debugPrint('🚨 AntiTheft ALARM for EPC: $epc (item ${item.sku})');
      } else {
        debugPrint('✅ Gate: sold item allowed $epc');
      }
    } catch (e) {
      debugPrint('AntiTheftService error: $e');
    }
  }
}
