import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rfid_service.dart';

final rfidServiceProvider = Provider<RfidService>((ref) {
  return RfidService();
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

  final RfidService _rfidService;

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
}

final rfidNotifierProvider = StateNotifierProvider<RfidNotifier, AsyncValue<RfidReaderStatus>>((ref) {
  final rfidService = ref.read(rfidServiceProvider);
  return RfidNotifier(rfidService);
});

// مزود للتحقق من حالة الاتصال
final isRfidConnectedProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(rfidNotifierProvider);
  return statusAsync.when(
    data: (status) => status == RfidReaderStatus.connected || status == RfidReaderStatus.scanning,
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
