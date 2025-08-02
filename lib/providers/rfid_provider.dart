import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rfid_service.dart';

final rfidServiceProvider = Provider<RfidServiceReal>((ref) {
  return RfidServiceReal();
});

final rfidStatusProvider = StreamProvider<RfidReaderStatus>((ref) {
  final rfidService = ref.read(rfidServiceProvider);
  return rfidService.statusStream;
});

final rfidTagProvider = StreamProvider<String>((ref) {
  final rfidService = ref.read(rfidServiceProvider);
  return rfidService.tagStream;
});

class RfidNotifier extends StateNotifier<AsyncValue<RfidReaderStatus>> {
  RfidNotifier(this._rfidService) : super(const AsyncValue.loading()) {
    _initialize();
  }

  final RfidServiceReal _rfidService;

  Future<void> _initialize() async {
    try {
      await _rfidService.initialize();
      state = AsyncValue.data(_rfidService.currentStatus);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> startScanning() async {
    state = const AsyncValue.loading();
    try {
      await _rfidService.startScanning();
      state = AsyncValue.data(_rfidService.currentStatus);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> stopScanning() async {
    state = const AsyncValue.loading();
    try {
      await _rfidService.stopScanning();
      state = AsyncValue.data(_rfidService.currentStatus);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> testConnection() async {
    state = const AsyncValue.loading();
    try {
      await _rfidService.testConnection();
      state = AsyncValue.data(_rfidService.currentStatus);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<String?> readSingleTag({Duration? timeout}) async {
    try {
      return await _rfidService.readSingleTag(
        timeout: timeout ?? const Duration(seconds: 10),
      );
    } catch (error) {
      return null;
    }
  }

  Future<void> disconnect() async {
    try {
      await _rfidService.disconnect();
      state = AsyncValue.data(_rfidService.currentStatus);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> connect({
    String? port,
    int? baudRate,
    int? timeout,
    String? deviceAddress,
    String? interface,
    double? startFreq,
    double? endFreq,
    bool singleFrequency = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _rfidService.connect(
        port: port ?? 'COM3',
        baudRate: baudRate ?? 115200,
        timeout: timeout ?? 5000,
        deviceAddress: deviceAddress,
        interface: interface,
        startFreq: startFreq,
        endFreq: endFreq,
        singleFrequency: singleFrequency,
      );
      state = AsyncValue.data(_rfidService.currentStatus);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> setPower(int power) async {
    try {
      await _rfidService.setPower(power);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  void setBeepOnRead(bool value) {
    _rfidService.setBeepOnRead(value);
  }

  /// إدخال بطاقة RFID يدوياً
  void inputRfidTag(String tagId) {
    _rfidService.inputRfidTag(tagId);
  }

  /// الحصول على معلومات الجهاز
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    try {
      return await _rfidService.getDeviceInfo();
    } catch (error) {
      return null;
    }
  }

  /// إعادة تهيئة الجهاز
  Future<bool> initializeDevice() async {
    try {
      final success = await _rfidService.initializeDevice();
      if (success) {
        state = AsyncValue.data(_rfidService.currentStatus);
      }
      return success;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  /// تشغيل صوت التنبيه
  Future<bool> playBeep() async {
    try {
      return await _rfidService.playBeep();
    } catch (error) {
      return false;
    }
  }

  /// مسح البطاقات المقروءة مؤخراً
  void clearRecentlyReadTags() {
    _rfidService.clearRecentlyReadTags();
  }
}

final rfidNotifierProvider =
    StateNotifierProvider<RfidNotifier, AsyncValue<RfidReaderStatus>>((ref) {
      final rfidService = ref.read(rfidServiceProvider);
      return RfidNotifier(rfidService);
    });

// مزود للتحقق من حالة الاتصال
final isRfidConnectedProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(rfidNotifierProvider);
  return statusAsync.when(
    data: (status) =>
        status == RfidReaderStatus.connected ||
        status == RfidReaderStatus.scanning,
    loading: () => false,
    error: (_, __) => false,
  );
});

// مزود للتحقق من حالة المسح
final isRfidScanningProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(rfidNotifierProvider);
  return statusAsync.when(
    data: (status) => status == RfidReaderStatus.scanning,
    loading: () => false,
    error: (_, __) => false,
  );
});
