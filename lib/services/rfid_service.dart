import 'dart:async';
import 'dart:math';

enum RfidReaderStatus {
  disconnected,
  connecting,
  connected,
  scanning,
  error,
}

/// # Placeholder RFID Service
/// 
/// This class simulates the behavior of a real RFID reader. It is designed to be
/// replaced with a concrete implementation that communicates with actual hardware
/// via a platform channel or a Flutter plugin.
/// 
/// It provides streams for status updates and scanned tags, which the UI can
/// listen to via the `RfidProvider`.
class RfidService {
  static final RfidService _instance = RfidService._internal();
  factory RfidService() => _instance;
  RfidService._internal();

  final StreamController<String> _tagStreamController = StreamController<String>.broadcast();
  final StreamController<RfidReaderStatus> _statusStreamController = StreamController<RfidReaderStatus>.broadcast();

  RfidReaderStatus _currentStatus = RfidReaderStatus.disconnected;
  RfidReaderStatus get currentStatus => _currentStatus;

  Stream<String> get tagStream => _tagStreamController.stream;
  Stream<RfidReaderStatus> get statusStream => _statusStreamController.stream;

  Timer? _scanningTimer;

  /// Simulates connecting to the RFID reader.
  Future<void> initialize() async {
    _currentStatus = RfidReaderStatus.connecting;
    _statusStreamController.add(_currentStatus);
    await Future.delayed(const Duration(seconds: 2)); // Simulate connection delay
    _currentStatus = RfidReaderStatus.connected;
    _statusStreamController.add(_currentStatus);
  }

  /// Simulates starting a scan for RFID tags.
  Future<bool> startScanning() async {
    if (_scanningTimer?.isActive ?? false) return true;

    _currentStatus = RfidReaderStatus.scanning;
    _statusStreamController.add(_currentStatus);
    
    // Periodically simulate finding a tag
    _scanningTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (Random().nextBool()) { // Simulate a 50% chance of finding a tag
        final tagId = 'RFID-${Random().nextInt(999999).toString().padLeft(6, '0')}';
        _tagStreamController.add(tagId);
      }
    });
    return true;
  }

  /// Simulates stopping the scan.
  Future<bool> stopScanning() async {
    _scanningTimer?.cancel();
    _currentStatus = RfidReaderStatus.connected;
    _statusStreamController.add(_currentStatus);
    return true;
  }

  /// Simulates a connection test.
  Future<bool> testConnection() async {
    _currentStatus = RfidReaderStatus.connecting;
    _statusStreamController.add(_currentStatus);
    await Future.delayed(const Duration(seconds: 1));
    _currentStatus = RfidReaderStatus.connected;
    _statusStreamController.add(_currentStatus);
    return true;
  }

  /// Simulates reading a single RFID tag with a timeout.
  Future<String?> readSingleTag({Duration? timeout}) async {
    final completer = Completer<String?>();
    StreamSubscription? subscription;
    Timer? timer;

    subscription = _tagStreamController.stream.listen((tag) {
      if (!completer.isCompleted) {
        completer.complete(tag);
        subscription?.cancel();
        timer?.cancel();
      }
    });

    timer = Timer(timeout ?? const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.complete(null); // Complete with null if timeout occurs
        subscription?.cancel();
      }
    });

    // Ensure scanning is active to receive tags
    startScanning();

    final tag = await completer.future;
    stopScanning(); // Stop scanning after reading a tag
    return tag;
  }

  /// Simulates disconnecting from the RFID reader.
  Future<void> disconnect() async {
    _scanningTimer?.cancel();
    _currentStatus = RfidReaderStatus.disconnected;
    _statusStreamController.add(_currentStatus);
  }

  void dispose() {
    _scanningTimer?.cancel();
    _tagStreamController.close();
    _statusStreamController.close();
  }
}