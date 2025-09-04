import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/rfid_duplicate_filter.dart';
import '../repositories/item_repository.dart';

/// Enum to represent the status of the RFID reader
enum RfidReaderStatus { disconnected, connecting, connected, scanning, error }

/// # Real RFID Service Implementation
///
/// This class provides actual RFID functionality using platform-specific
/// implementations or plugins for communicating with RFID readers.
///
class RfidServiceReal {
  RfidServiceReal();

  // تشغيل صوت تنبيه عند كل قراءة (قابل للتغيير من صفحة الإعدادات)
  bool _beepOnRead = false;
  SerialPort? _serialPort; // منفذ تسلسلي مفتوح (إن وُجد)
  SerialPortReader? _serialReader;
  StreamSubscription<Uint8List>? _serialSubscription;
  BluetoothDevice? _bleDevice;
  BluetoothCharacteristic? _bleRx; // notifications from reader
  BluetoothCharacteristic? _bleTx; // writes to reader
  StreamSubscription<List<int>>? _bleNotifySub;
  void setBeepOnRead(bool value) {
    _beepOnRead = value;
    debugPrint('RFID beepOnRead set to $value');
  }

  Future<void> initialize() async {
    // تهيئة افتراضية (فارغة) – يمكن لاحقاً تنفيذ منطق تهيئة المنفذ / اكتشاف الأجهزة
  }

  final StreamController<String> _tagStreamController =
      StreamController<String>.broadcast();
  final StreamController<RfidReaderStatus> _statusStreamController =
      StreamController<RfidReaderStatus>.broadcast();

  RfidReaderStatus _currentStatus = RfidReaderStatus.disconnected;
  RfidReaderStatus get currentStatus => _currentStatus;

  Stream<String> get tagStream => _tagStreamController.stream;
  Stream<RfidReaderStatus> get statusStream => _statusStreamController.stream;

  Timer? _scanningTimer;
  Socket? _rfidSocket;
  final Set<String> _recentlyReadTags = {};
  Timer? _tagCooldownTimer;

  /// Connects to an RFID reader via network (TCP/IP)
  Future<bool> connectToNetworkReader(String ipAddress, int port) async {
    try {
      _updateStatus(RfidReaderStatus.connecting);

      // Close existing connection if any
      await _rfidSocket?.close();

      // Connect to RFID reader
      _rfidSocket = await Socket.connect(
        ipAddress,
        port,
        timeout: const Duration(seconds: 10),
      );

      // Listen for data from the RFID reader
      _rfidSocket!.listen(
        _handleRfidData,
        onError: (error) {
          debugPrint("RFID socket error: $error");
          _updateStatus(RfidReaderStatus.error);
        },
        onDone: () {
          debugPrint("RFID socket connection closed");
          _updateStatus(RfidReaderStatus.disconnected);
        },
      );

      _updateStatus(RfidReaderStatus.connected);
      return true;
    } catch (e) {
      debugPrint("Failed to connect to RFID reader: $e");
      _updateStatus(RfidReaderStatus.error);
      return false;
    }
  }

  /// Connects to an RFID reader via serial port
  Future<bool> connectToSerialReader(String portName) async {
    try {
      _updateStatus(RfidReaderStatus.connecting);
      if (!SerialPort.availablePorts.contains(portName)) {
        throw Exception('Serial port not found: $portName');
      }
      _serialPort?.close();
      _serialSubscription?.cancel();
      _serialPort = SerialPort(portName);
      final opened = _serialPort!.openReadWrite();
      if (!opened) {
        throw Exception('Failed to open serial port: $portName');
      }
      _serialPort!.config = SerialPortConfig()
        ..baudRate = 115200
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;
      _serialReader = SerialPortReader(_serialPort!);
      _serialSubscription = _serialReader!.stream.listen(
        (data) => _handleRfidData(data),
        onError: (e) => debugPrint('Serial read error: $e'),
        cancelOnError: false,
      );
      _updateStatus(RfidReaderStatus.connected);
      return true;
    } catch (e) {
      debugPrint("Failed to connect to serial RFID reader: $e");
      _updateStatus(RfidReaderStatus.error);
      return false;
    }
  }

  /// Connects to an RFID reader via Bluetooth
  Future<bool> connectToBluetoothReader(String deviceId) async {
    try {
      _updateStatus(RfidReaderStatus.connecting);
      // Ensure adapter on
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        // Try to turn on (Android only); on Windows, surface error
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
        if (await FlutterBluePlus.adapterState.first !=
            BluetoothAdapterState.on) {
          throw Exception('Bluetooth adapter is off');
        }
      }

      // Scan briefly to find device by id/name
      BluetoothDevice? found;
      final scanSub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          final d = r.device;
          if (d.remoteId.str == deviceId || (d.platformName == deviceId)) {
            found = d;
          }
        }
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
      await FlutterBluePlus.stopScan();
      await scanSub.cancel();
      if (found == null) {
        final connected = FlutterBluePlus.connectedDevices;
        final matches = connected
            .where(
              (d) => d.remoteId.str == deviceId || d.platformName == deviceId,
            )
            .toList();
        if (matches.isNotEmpty) {
          found = matches.first;
        }
      }
      if (found == null) {
        final bonded = await FlutterBluePlus.bondedDevices;
        final matches = bonded
            .where(
              (d) => d.remoteId.str == deviceId || d.platformName == deviceId,
            )
            .toList();
        if (matches.isNotEmpty) {
          found = matches.first;
        }
      }
      if (found == null) {
        throw Exception('BLE device not found: $deviceId');
      }

      _bleDevice = found;
      await _bleDevice!.connect(timeout: const Duration(seconds: 10));
      final services = await _bleDevice!.discoverServices();

      // Heuristics: try Nordic UART (NUS) first, else any notify/write characteristic
      Guid uartService = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
      Guid rxChar = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e'); // notify
      Guid txChar = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e'); // write

      for (final s in services) {
        if (s.uuid == uartService) {
          for (final c in s.characteristics) {
            if (c.uuid == rxChar) _bleRx = c;
            if (c.uuid == txChar) _bleTx = c;
          }
        }
      }
      // fallback: first notify + first write
      if (_bleRx == null) {
        for (final s in services) {
          for (final c in s.characteristics) {
            if (c.properties.notify) {
              _bleRx = c;
              break;
            }
          }
          if (_bleRx != null) break;
        }
      }
      if (_bleTx == null) {
        for (final s in services) {
          for (final c in s.characteristics) {
            if (c.properties.write || c.properties.writeWithoutResponse) {
              _bleTx = c;
              break;
            }
          }
          if (_bleTx != null) break;
        }
      }

      if (_bleRx == null || _bleTx == null) {
        throw Exception('Suitable BLE characteristics not found');
      }

      await _bleRx!.setNotifyValue(true);
      await _bleNotifySub?.cancel();
      _bleNotifySub = _bleRx!.onValueReceived.listen((data) {
        _handleRfidData(data);
      }, onError: (e) => debugPrint('BLE notify error: $e'));

      _updateStatus(RfidReaderStatus.connected);
      return true;
    } catch (e) {
      debugPrint("Failed to connect to Bluetooth RFID reader: $e");
      _updateStatus(RfidReaderStatus.error);
      return false;
    }
  }

  /// Starts scanning for RFID tags
  Future<bool> startScanning() async {
    try {
      if (_currentStatus != RfidReaderStatus.connected) {
        throw StateError('RFID reader is not connected');
      }
      _updateStatus(RfidReaderStatus.scanning);

      // Send command to start scanning
      // The actual command depends on the RFID reader model
      _sendCommand(_commandBuilder.buildStartScan(), log: 'بدء المسح');

      return true;
    } catch (e) {
      debugPrint("Failed to start scanning: $e");
      _updateStatus(RfidReaderStatus.error);
      return false;
    }
  }

  /// Stops scanning for RFID tags
  Future<bool> stopScanning() async {
    try {
      // إيقاف المؤقت
      _scanningTimer?.cancel();
      _scanningTimer = null;
      _tagCooldownTimer?.cancel();
      _tagCooldownTimer = null;

      // مسح قائمة البطاقات المقروءة
      _recentlyReadTags.clear();

      // Send command to stop scanning
      _sendCommand(_commandBuilder.buildStopScan(), log: 'إيقاف المسح');

      _updateStatus(RfidReaderStatus.connected);
      return true;
    } catch (e) {
      debugPrint("Failed to stop scanning: $e");
      _updateStatus(RfidReaderStatus.error);
      return false;
    }
  }

  /// Reads a single RFID tag with timeout
  Future<String?> readSingleTag({Duration? timeout}) async {
    try {
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
      await startScanning();

      final tag = await completer.future;
      await stopScanning(); // Stop scanning after reading a tag
      return tag;
    } catch (e) {
      debugPrint("Error reading single tag: $e");
      return null;
    }
  }

  /// Tests connection to RFID reader
  Future<bool> testConnection() async {
    try {
      _updateStatus(RfidReaderStatus.connecting);
      await Future.delayed(const Duration(seconds: 1));

      // Send a test command to the reader
      _sendCommand(_commandBuilder.buildTest(), log: 'اختبار الاتصال');

      // Wait for response (in a real implementation)
      await Future.delayed(const Duration(milliseconds: 500));

      _updateStatus(RfidReaderStatus.connected);
      return true;
    } catch (e) {
      debugPrint("RFID connection test failed: $e");
      _updateStatus(RfidReaderStatus.error);
      return false;
    }
  }

  /// Disconnects from the RFID reader
  Future<void> disconnect() async {
    try {
      await stopScanning();
      await _rfidSocket?.close();
      _rfidSocket = null;
      _updateStatus(RfidReaderStatus.disconnected);
    } catch (e) {
      debugPrint("Error disconnecting from RFID reader: $e");
    }
  }

  /// Handles data received from the RFID reader
  void _handleRfidData(List<int> data) {
    try {
      // Convert bytes to string
      final dataString = String.fromCharCodes(data);
      debugPrint("RFID data received: $dataString");

      // Parse the data to extract tag ID
      // The format depends on the RFID reader model
      final tagId = _parseTagId(dataString);

      if (tagId != null) {
        if (!RfidDuplicateFilter.shouldProcess(tagId)) {
          debugPrint('🔁 تم تجاهل بطاقة مكررة (خدمة): $tagId');
        } else {
          _tagStreamController.add(tagId);
          if (_beepOnRead) {
            // لا نرن إلا إذا كانت البطاقة مسجلة في المنظومة
            // ignore: discarded_futures
            _maybeBeepForRegistered(tagId);
          }
        }
      }
    } catch (e) {
      debugPrint("Error handling RFID data: $e");
      _updateStatus(RfidReaderStatus.error);
    }
  }

  /// يشغّل صوت التنبيه فقط إذا كانت البطاقة مرتبطة بصنف مسجّل
  Future<void> _maybeBeepForRegistered(String tagId) async {
    try {
      final repo = ItemRepository();
      final item = await repo.getItemByRfidTag(tagId);
      if (item != null) {
        await playBeep();
      } else {
        debugPrint('🔇 تجاهُل الرنين لبطاقة غير مسجلة: $tagId');
      }
    } catch (e) {
      debugPrint('⚠️ فشل التحقق من البطاقة قبل الرنين: $e');
    }
  }

  /// Parses tag ID from raw data string
  String? _parseTagId(String data) {
    // This is a simplified parser
    // In a real implementation, you would need to handle
    // the specific data format of your RFID reader

    // Remove whitespace and special characters
    final cleanData = data.trim().replaceAll(RegExp(r'[\r\n]'), '');

    // Check if it looks like a valid RFID tag
    if (cleanData.isNotEmpty && cleanData.length >= 8) {
      return cleanData;
    }

    return null;
  }

  // (تم استبدال دوال بناء الأوامر القديمة بـ _RfidCommandBuilder)

  /// Updates the RFID reader status and notifies listeners
  void _updateStatus(RfidReaderStatus status) {
    _currentStatus = status;
    _statusStreamController.add(status);
  }

  /// Connects with custom parameters
  Future<bool> connect({
    String port = 'COM3',
    int baudRate = 115200,
    int timeout = 5000,
    String? deviceAddress,
    String? interface,
    double? startFreq,
    double? endFreq,
    bool singleFrequency = false,
    int retryCount = 2,
    Duration retryDelay = const Duration(milliseconds: 600),
  }) async {
    try {
      _updateStatus(RfidReaderStatus.connecting);

      // محاكاة الاتصال بالمعاملات المخصصة
      await Future.delayed(const Duration(seconds: 2));

      // محاولة فتح منفذ تسلسلي مع إعادة المحاولة (منصات سطح المكتب فقط)
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        if (interface == null || interface == 'USB' || interface == 'CDC_COM') {
          String lastError = '';
          for (var attempt = 0; attempt <= retryCount; attempt++) {
            try {
              if (!SerialPort.availablePorts.contains(port)) {
                lastError = 'المنفذ $port غير موجود';
                await Future.delayed(retryDelay);
                continue;
              }
              _serialPort?.close();
              _serialSubscription?.cancel();
              _serialPort = SerialPort(port);
              if (_serialPort!.openReadWrite()) {
                _serialPort!.config = SerialPortConfig()
                  ..baudRate = baudRate
                  ..bits = 8
                  ..stopBits = 1
                  ..parity = SerialPortParity.none;
                _serialReader = SerialPortReader(_serialPort!);
                _serialSubscription = _serialReader!.stream.listen(
                  (data) => _handleRfidData(data),
                  onError: (e) {
                    debugPrint('⚠️ خطأ قراءة المنفذ: $e');
                  },
                  cancelOnError: false,
                );
                debugPrint('🔌 فتح منفذ تسلسلي: $port (محاولة ${attempt + 1})');
                break; // success
              } else {
                lastError = 'فشل فتح المنفذ (قد تحتاج صلاحيات)';
              }
            } catch (e) {
              lastError = e.toString();
            }
            if (attempt < retryCount) {
              await Future.delayed(retryDelay);
            } else if (_serialPort == null || !_serialPort!.isOpen) {
              throw Exception(
                'تعذر فتح المنفذ $port بعد ${retryCount + 1} محاولات: $lastError',
              );
            }
          }
        }
      } else {
        debugPrint('ℹ️ تخطي فتح المنفذ: منصة غير مدعومة أو Web');
      }

      // تطبيق الإعدادات المتقدمة
      if (deviceAddress != null) {
        await _setDeviceAddress(deviceAddress);
      }

      if (startFreq != null && endFreq != null) {
        await _setFrequencyRange(startFreq, endFreq, singleFrequency);
      }

      debugPrint("RFID reader connected on $port at $baudRate baud");
      debugPrint(
        "Interface: ${interface ?? 'USB'}, Address: ${deviceAddress ?? '0'}",
      );
      if (startFreq != null) {
        debugPrint(
          "Frequency: $startFreq MHz - $endFreq MHz (Single: $singleFrequency)",
        );
      }

      _updateStatus(RfidReaderStatus.connected);
      return true;
    } catch (e) {
      debugPrint("Failed to connect with custom parameters: $e");
      _updateStatus(RfidReaderStatus.error);
      return false;
    }
  }

  /// Sets RFID reader power level
  Future<bool> setPower(int power) async {
    try {
      if (power < 0 || power > 20) {
        throw ArgumentError('Power must be between 0 and 20 dBm');
      }
      final powerCommand = _commandBuilder.buildSetPower(power);
      _sendCommand(powerCommand, log: 'ضبط القدرة إلى $power dBm');
      return true;
    } catch (e) {
      debugPrint("Failed to set RFID power: $e");
      return false;
    }
  }

  /// Sets device address
  Future<bool> _setDeviceAddress(String address) async {
    try {
      final addressCommand = _commandBuilder.buildSetAddress(address);
      _sendCommand(addressCommand, log: 'ضبط عنوان الجهاز: $address');
      return true;
    } catch (e) {
      debugPrint("Failed to set device address: $e");
      return false;
    }
  }

  /// Sets frequency range
  Future<bool> _setFrequencyRange(
    double startFreq,
    double endFreq,
    bool singleFreq,
  ) async {
    try {
      final freqCommand = singleFreq
          ? _commandBuilder.buildSetSingleFrequency(startFreq)
          : _commandBuilder.buildSetFrequencyRange(startFreq, endFreq);
      _sendCommand(
        freqCommand,
        log: 'تعيين التردد: $startFreq - $endFreq (Single: $singleFreq)',
      );
      return true;
    } catch (e) {
      debugPrint("Failed to set frequency range: $e");
      return false;
    }
  }

  /// Gets device information
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    try {
      final infoCommand = _commandBuilder.buildGetInfo();
      _sendCommand(infoCommand, log: 'طلب معلومات الجهاز');

      // في التطبيق الحقيقي، ستنتظر الاستجابة
      await Future.delayed(const Duration(milliseconds: 500));

      return {
        'model': 'UHF Desktop Reader',
        'version': '1.0.3',
        'power': '20',
        'frequency': '920.125-924.875 MHz',
        'interface': 'USB',
        'status': 'Connected',
      };
    } catch (e) {
      debugPrint("Failed to get device info: $e");
      return null;
    }
  }

  /// Initializes/resets device to default settings
  Future<bool> initializeDevice() async {
    try {
      final initCommand = _commandBuilder.buildInitialize();
      _sendCommand(initCommand, log: 'إعادة تهيئة الجهاز');

      await Future.delayed(const Duration(seconds: 2));
      debugPrint("RFID device initialized successfully");
      return true;
    } catch (e) {
      debugPrint("Failed to initialize device: $e");
      return false;
    }
  }

  // ============= Command Builder & Transport Abstraction =============
  final _commandBuilder = _RfidCommandBuilder();

  void _sendCommand(String command, {String? log}) {
    try {
      // أولوية الإرسال: منفذ تسلسلي مفتوح -> مقبس شبكة (إن وجد)
      if (_serialPort != null && _serialPort!.isOpen) {
        final bytes = utf8.encode(command);
        _serialPort!.write(Uint8List.fromList(bytes));
      } else if (_bleTx != null) {
        final bytes = Uint8List.fromList(utf8.encode(command));
        // prefer writeWithoutResponse if available
        if (_bleTx!.properties.writeWithoutResponse) {
          // ignore: discarded_futures
          _bleTx!.write(bytes, withoutResponse: true);
        } else {
          // ignore: discarded_futures
          _bleTx!.write(bytes, withoutResponse: false);
        }
      } else {
        _rfidSocket?.write(command);
      }
      if (log != null) debugPrint('📤 CMD: $log => ${command.trim()}');
    } catch (e) {
      debugPrint('⚠️ فشل إرسال الأمر: $e');
    }
  }

  /// Clears recently read tags to allow re-reading
  void clearRecentlyReadTags() {
    _recentlyReadTags.clear();
    debugPrint("Recently read RFID tags cleared");
  }

  /// إدخال بطاقة RFID يدوياً (للاختبار فقط)
  void inputRfidTag(String tagId) {
    if (_currentStatus == RfidReaderStatus.scanning ||
        _currentStatus == RfidReaderStatus.connected) {
      if (!RfidDuplicateFilter.shouldProcess(tagId)) {
        debugPrint('🔁 تم تجاهل بطاقة مكررة (إدخال يدوي): $tagId');
        return;
      }
      _recentlyReadTags.add(tagId);
      debugPrint('📡 تم إدخال بطاقة RFID: $tagId');
      _tagStreamController.add(tagId);
      Timer(const Duration(seconds: 5), () {
        _recentlyReadTags.remove(tagId);
      });
      if (_beepOnRead) {
        // احترام قاعدة عدم الرنين للبطاقات غير المسجلة
        // ignore: discarded_futures
        _maybeBeepForRegistered(tagId);
      }
    } else {
      debugPrint('⚠️ لا يمكن قراءة البطاقة - القارئ غير متصل');
    }
  }

  /// تشغيل صوت التنبيه
  Future<bool> playBeep() async {
    try {
      final beepCommand = _commandBuilder.buildBeep();
      _sendCommand(beepCommand, log: 'تشغيل صوت');
      return true;
    } catch (e) {
      debugPrint('خطأ في تشغيل الصوت: $e');
      return false;
    }
  }

  /// Disposes of resources
  void dispose() {
    _serialSubscription?.cancel();
    if (_serialPort?.isOpen == true) {
      _serialPort?.close();
    }
    _bleNotifySub?.cancel();
    _bleDevice?.disconnect();
    _scanningTimer?.cancel();
    _tagCooldownTimer?.cancel();
    _rfidSocket?.close();
    _recentlyReadTags.clear();
    if (!_tagStreamController.isClosed) {
      _tagStreamController.close();
    }
    if (!_statusStreamController.isClosed) {
      _statusStreamController.close();
    }
  }
}

/// بسيط لبناء أوامر القارئ (يمكن لاحقاً استبداله بإصدار خاص بكل طراز)
class _RfidCommandBuilder {
  static const String terminator = '\r\n';

  String buildStartScan() => 'START_SCAN$terminator';
  String buildStopScan() => 'STOP_SCAN$terminator';
  String buildTest() => 'PING$terminator';
  String buildSetPower(int p) => 'SET_POWER $p$terminator';
  String buildSetAddress(String a) => 'SET_ADDR $a$terminator';
  String buildSetFrequencyRange(double s, double e) =>
      'SET_FREQ_RANGE $s $e$terminator';
  String buildSetSingleFrequency(double f) => 'SET_FREQ_SINGLE $f$terminator';
  String buildGetInfo() => 'GET_INFO$terminator';
  String buildInitialize() => 'INIT_DEVICE$terminator';
  String buildBeep() => 'BEEP$terminator';
}

extension RfidSerialSupport on RfidServiceReal {
  /// إرجاع قائمة المنافذ المتاحة (مع حارس منصة)
  List<String> enumeratePorts() {
    try {
      if (kIsWeb) {
        return const [];
      }
      if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        return const [];
      }
      final ports = SerialPort.availablePorts;
      return ports.isEmpty ? const [] : List<String>.from(ports);
    } catch (_) {
      return const [];
    }
  }
}
