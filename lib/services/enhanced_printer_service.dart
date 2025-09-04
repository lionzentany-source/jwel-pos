import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/printer_settings.dart';
import '../models/invoice_render_data.dart';

/// خدمة الطباعة المحسنة التي تستفيد من الأدوات الصينية المتقدمة
class EnhancedPrinterService {
  static final EnhancedPrinterService _instance =
      EnhancedPrinterService._internal();
  factory EnhancedPrinterService() => _instance;
  EnhancedPrinterService._internal();

  /// مسار أداة الطباعة الصينية
  late String _printerToolPath;

  /// قائمة الطابعات المكتشفة
  final List<PrinterInfo> _discoveredPrinters = [];

  /// الطابعة المحددة حالياً
  PrinterInfo? _selectedPrinter;

  /// تهيئة الخدمة
  Future<bool> initialize() async {
    try {
      debugPrint('تهيئة خدمة الطباعة المحسنة...');

      // البحث عن أداة الطباعة الصينية
      _printerToolPath = await _findPrinterTool();

      if (_printerToolPath.isEmpty) {
        debugPrint('لم يتم العثور على أداة الطباعة الصينية');
        return false;
      }

      debugPrint('تم العثور على أداة الطباعة: $_printerToolPath');
      return true;
    } catch (e) {
      debugPrint('خطأ في تهيئة خدمة الطباعة: $e');
      return false;
    }
  }

  /// البحث عن أداة الطباعة الصينية
  Future<String> _findPrinterTool() async {
    final possiblePaths = [
      'driver and tool/打印机测试工具V2.0.exe',
      'driver and tool/tool_extracted/打印机测试工具V2.0.exe',
      '打印机测试工具V2.0.exe',
      'printer_tool.exe',
    ];

    for (final relativePath in possiblePaths) {
      final fullPath = path.join(Directory.current.path, relativePath);
      final file = File(fullPath);

      if (await file.exists()) {
        debugPrint('تم العثور على أداة الطباعة في: $fullPath');
        return fullPath;
      }
    }

    debugPrint('لم يتم العثور على أداة الطباعة في المسارات المتوقعة');
    return '';
  }

  /// اكتشاف جميع الطابعات المتاحة
  Future<List<PrinterInfo>> discoverPrinters() async {
    try {
      debugPrint('بدء اكتشاف الطابعات...');
      _discoveredPrinters.clear();

      // اكتشاف طابعات Windows
      await _discoverWindowsPrinters();

      // اكتشاف طابعات USB
      await _discoverUSBPrinters();

      // اكتشاف طابعات الشبكة
      await _discoverNetworkPrinters();

      // اكتشاف طابعات البلوتوث
      await _discoverBluetoothPrinters();

      debugPrint('تم اكتشاف ${_discoveredPrinters.length} طابعة');
      return _discoveredPrinters;
    } catch (e) {
      debugPrint('خطأ في اكتشاف الطابعات: $e');
      return [];
    }
  }

  /// اكتشاف طابعات Windows
  Future<void> _discoverWindowsPrinters() async {
    try {
      debugPrint('اكتشاف طابعات Windows...');

      final result = await Process.run('powershell', [
        '-Command',
        'Get-Printer | ConvertTo-Json',
      ], runInShell: true);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        if (output.isNotEmpty && output != 'null') {
          try {
            final dynamic jsonData = jsonDecode(output);
            final List<dynamic> printers = jsonData is List
                ? jsonData
                : [jsonData];

            for (final printer in printers) {
              if (printer is Map<String, dynamic>) {
                _discoveredPrinters.add(
                  PrinterInfo(
                    name: printer['Name'] ?? 'Unknown',
                    type: PrinterType.windows,
                    connectionString: printer['Name'] ?? '',
                    isDefault: printer['Default'] == true,
                    isAvailable: printer['PrinterStatus'] == 'Normal',
                    details: {
                      'status': printer['PrinterStatus'] ?? 'Unknown',
                      'location': printer['Location'] ?? '',
                      'comment': printer['Comment'] ?? '',
                    },
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint('خطأ في تحليل بيانات طابعات Windows: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في اكتشاف طابعات Windows: $e');
    }
  }

  /// اكتشاف طابعات USB
  Future<void> _discoverUSBPrinters() async {
    try {
      debugPrint('اكتشاف طابعات USB...');

      final result = await Process.run('wmic', [
        'path',
        'Win32_USBDevice',
        'where',
        'DeviceID like "%PRINT%"',
        'get',
        'DeviceID,Name',
      ], runInShell: true);

      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.contains('USB') && line.contains('VID_')) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final deviceId = parts.firstWhere(
                (p) => p.contains('USB'),
                orElse: () => '',
              );
              final name = parts.skip(1).join(' ').trim();

              if (deviceId.isNotEmpty && name.isNotEmpty) {
                _discoveredPrinters.add(
                  PrinterInfo(
                    name: name,
                    type: PrinterType.usb,
                    connectionString: deviceId,
                    isDefault: false,
                    isAvailable: true,
                    details: {'deviceId': deviceId},
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في اكتشاف طابعات USB: $e');
    }
  }

  /// اكتشاف طابعات الشبكة
  Future<void> _discoverNetworkPrinters() async {
    try {
      debugPrint('اكتشاف طابعات الشبكة...');

      // البحث السريع في نطاق محدود
      final subnet = await _getLocalSubnet();
      if (subnet.isNotEmpty) {
        final futures = <Future>[];

        // البحث في نطاق محدود فقط للسرعة
        for (int i = 1; i <= 20; i++) {
          final ip = '$subnet.$i';
          futures.add(_checkNetworkPrinter(ip, 9100));
        }

        await Future.wait(futures);
      }
    } catch (e) {
      debugPrint('خطأ في اكتشاف طابعات الشبكة: $e');
    }
  }

  /// الحصول على الشبكة المحلية
  Future<String> _getLocalSubnet() async {
    try {
      final result = await Process.run('ipconfig', [], runInShell: true);
      final lines = result.stdout.toString().split('\n');

      for (final line in lines) {
        if (line.contains('IPv4 Address') || line.contains('IP Address')) {
          final match = RegExp(r'(\d+\.\d+\.\d+)\.\d+').firstMatch(line);
          if (match != null) {
            return match.group(1)!;
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في الحصول على الشبكة المحلية: $e');
    }
    return '';
  }

  /// فحص طابعة شبكة محددة
  Future<void> _checkNetworkPrinter(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 500),
      );
      await socket.close();

      _discoveredPrinters.add(
        PrinterInfo(
          name: 'Network Printer ($ip)',
          type: PrinterType.network,
          connectionString: '$ip:$port',
          isDefault: false,
          isAvailable: true,
          details: {'ip': ip, 'port': port.toString()},
        ),
      );

      debugPrint('تم العثور على طابعة شبكة: $ip:$port');
    } catch (e) {
      // تجاهل الأخطاء - الطابعة غير متاحة
    }
  }

  /// اكتشاف طابعات البلوتوث
  Future<void> _discoverBluetoothPrinters() async {
    try {
      debugPrint('اكتشاف طابعات البلوتوث...');

      final result = await Process.run('powershell', [
        '-Command',
        r'Get-PnpDevice -Class "Printer" | Where-Object {$_.InstanceId -like "*BTHENUM*"} | ConvertTo-Json',
      ], runInShell: true);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        if (output.isNotEmpty && output != 'null') {
          try {
            final dynamic jsonData = jsonDecode(output);
            final List<dynamic> devices = jsonData is List
                ? jsonData
                : [jsonData];

            for (final device in devices) {
              if (device is Map<String, dynamic>) {
                _discoveredPrinters.add(
                  PrinterInfo(
                    name: device['FriendlyName'] ?? 'Bluetooth Printer',
                    type: PrinterType.bluetooth,
                    connectionString: device['InstanceId'] ?? '',
                    isDefault: false,
                    isAvailable: device['Status'] == 'OK',
                    details: {
                      'instanceId': device['InstanceId'] ?? '',
                      'status': device['Status'] ?? '',
                    },
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint('خطأ في تحليل بيانات طابعات البلوتوث: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في اكتشاف طابعات البلوتوث: $e');
    }
  }

  /// اختبار طباعة على طابعة محددة
  Future<bool> testPrint(PrinterInfo printer) async {
    try {
      debugPrint('اختبار الطباعة على: ${printer.name}');

      final testContent = _generateTestContent();
      final tempFile = await _createTempFile(testContent);

      final success = await _executePrintCommand(printer, tempFile.path);

      // حذف الملف المؤقت
      await tempFile.delete();

      if (success) {
        debugPrint('نجح اختبار الطباعة على: ${printer.name}');
      } else {
        debugPrint('فشل اختبار الطباعة على: ${printer.name}');
      }

      return success;
    } catch (e) {
      debugPrint('خطأ في اختبار الطباعة: $e');
      return false;
    }
  }

  /// طباعة فاتورة
  Future<bool> printInvoice(
    PrinterInfo printer,
    InvoiceRenderData invoiceRenderData,
  ) async {
    try {
      debugPrint('طباعة فاتورة على: ${printer.name}');

      final invoiceContent = _generateInvoiceContent(invoiceRenderData);
      final tempFile = await _createTempFile(invoiceContent);

      final success = await _executePrintCommand(printer, tempFile.path);

      // حذف الملف المؤقت
      await tempFile.delete();

      if (success) {
        debugPrint('تم طباعة الفاتورة بنجاح على: ${printer.name}');
      } else {
        debugPrint('فشل في طباعة الفاتورة على: ${printer.name}');
      }

      return success;
    } catch (e) {
      debugPrint('خطأ في طباعة الفاتورة: $e');
      return false;
    }
  }

  /// تنفيذ أمر الطباعة باستخدام الأداة الصينية
  Future<bool> _executePrintCommand(
    PrinterInfo printer,
    String filePath,
  ) async {
    try {
      if (_printerToolPath.isEmpty) {
        debugPrint('أداة الطباعة غير متاحة');
        return false;
      }

      final List<String> args = [];

      switch (printer.type) {
        case PrinterType.usb:
          args.addAll(['-type', 'usb', '-device', printer.connectionString]);
          break;
        case PrinterType.network:
          final parts = printer.connectionString.split(':');
          final ip = parts[0];
          final port = parts.length > 1 ? parts[1] : '9100';
          args.addAll(['-type', 'network', '-ip', ip, '-port', port]);
          break;
        case PrinterType.bluetooth:
          args.addAll([
            '-type',
            'bluetooth',
            '-device',
            printer.connectionString,
          ]);
          break;
        case PrinterType.windows:
          args.addAll(['-type', 'windows', '-printer', printer.name]);
          break;
        case PrinterType.thermal:
          args.addAll([
            '-type',
            'thermal',
            '-device',
            printer.connectionString,
          ]);
          break;
      }

      args.addAll(['-file', filePath]);

      debugPrint('تنفيذ أمر الطباعة: $_printerToolPath ${args.join(' ')}');

      final result = await Process.run(
        _printerToolPath,
        args,
        runInShell: true,
      );

      if (result.exitCode == 0) {
        debugPrint('تم تنفيذ أمر الطباعة بنجاح');
        return true;
      } else {
        debugPrint('فشل في تنفيذ أمر الطباعة: ${result.stderr}');
        return false;
      }
    } catch (e) {
      debugPrint('خطأ في تنفيذ أمر الطباعة: $e');
      return false;
    }
  }

  /// إنشاء ملف مؤقت للطباعة
  Future<File> _createTempFile(String content) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      path.join(
        tempDir.path,
        'print_${DateTime.now().millisecondsSinceEpoch}.txt',
      ),
    );

    await tempFile.writeAsString(content, encoding: utf8);
    return tempFile;
  }

  /// توليد محتوى اختبار الطباعة
  String _generateTestContent() {
    // إضافة أوامر قص تلقائي (GS V 1) في النهاية
    final cutCommand = String.fromCharCodes([0x1D, 0x56, 0x01]);
    return '''
================================================
           اختبار الطباعة - نظام جوهر
================================================

التاريخ: ${DateTime.now().toString().split('.')[0]}
الطابعة: ${_selectedPrinter?.name ?? 'غير محدد'}

------------------------------------------------

هذه صفحة اختبار للتأكد من عمل الطابعة بشكل صحيح.

إذا كنت تقرأ هذا النص، فإن الطابعة تعمل بشكل ممتاز!

------------------------------------------------

الميزات المدعومة:
✓ النصوص العربية
✓ الأرقام والرموز
✓ التنسيق والجداول
✓ الطباعة الحرارية

================================================
           نظام جوهر - اختبار مكتمل
================================================
$cutCommand''';
  }

  /// توليد محتوى الفاتورة
  String _generateInvoiceContent(InvoiceRenderData invoiceRenderData) {
    final storeName = invoiceRenderData.storeName;
    final storeAddress = invoiceRenderData.storeAddress ?? 'العنوان غير محدد';
    final storePhone = invoiceRenderData.storePhone ?? 'الهاتف غير محدد';
    final invoiceNumber = invoiceRenderData.invoiceNumber;
    final customerName = invoiceRenderData.customerName ?? 'عميل';
    final items = invoiceRenderData.items;
    final subtotal = invoiceRenderData.subtotal;
    final discount = invoiceRenderData.discount;
    final tax = invoiceRenderData.tax;
    final total = invoiceRenderData.total;
    final paymentMethod = invoiceRenderData.paymentMethod;

    final buffer = StringBuffer();

    // رأس الفاتورة
    buffer.writeln('================================================');
    buffer.writeln('           $storeName');
    buffer.writeln('================================================');
    buffer.writeln('العنوان: $storeAddress');
    buffer.writeln('الهاتف: $storePhone');
    buffer.writeln('------------------------------------------------');
    buffer.writeln('');
    buffer.writeln('رقم الفاتورة: $invoiceNumber');
    buffer.writeln(
      'التاريخ: ${invoiceRenderData.date.toString().split(' ')[0]}',
    );
    buffer.writeln(
      'الوقت: ${invoiceRenderData.date.toString().split(' ')[1].split('.')[0]}',
    );
    buffer.writeln('العميل: $customerName');
    buffer.writeln('');
    buffer.writeln('------------------------------------------------');
    buffer.writeln('الصنف                    الكمية    السعر    الإجمالي');
    buffer.writeln('------------------------------------------------');

    // الأصناف
    for (final item in items) {
      final name = item.item.sku;
      final quantity = item.quantity.toString();
      final price = item.unitPrice.toStringAsFixed(2);
      final itemTotal = item.totalPrice.toStringAsFixed(2);

      buffer.writeln(
        '${name.padRight(25)} ${quantity.padLeft(6)} ${price.padLeft(8)} ${itemTotal.padLeft(8)}',
      );
    }

    buffer.writeln('------------------------------------------------');
    buffer.writeln(
      'المجموع الفرعي:                           ${subtotal.toStringAsFixed(2)} د.ل',
    );
    if (discount > 0) {
      buffer.writeln(
        'الخصم:                                    ${discount.toStringAsFixed(2)} د.ل',
      );
    }
    if (tax > 0) {
      buffer.writeln(
        'الضريبة:                                 ${tax.toStringAsFixed(2)} د.ل',
      );
    }
    buffer.writeln('================================================');
    buffer.writeln(
      'الإجمالي:                                ${total.toStringAsFixed(2)} د.ل',
    );
    buffer.writeln('================================================');
    buffer.writeln('');
    buffer.writeln('طريقة الدفع: $paymentMethod');
    buffer.writeln('');
    buffer.writeln('           شكراً لزيارتكم');
    buffer.writeln('================================================');
    // أمر القص (GS V 1) لقص الورق تلقائياً
    buffer.write(String.fromCharCodes([0x1D, 0x56, 0x01]));
    return buffer.toString();
  }

  /// إضافة طابعة مخصصة
  Future<bool> addCustomPrinter(PrinterInfo printer) async {
    try {
      final testResult = await testPrint(printer);
      if (testResult) {
        _discoveredPrinters.add(printer);
        debugPrint('تم إضافة الطابعة المخصصة: ${printer.name}');
        return true;
      } else {
        debugPrint('فشل في اختبار الطابعة المخصصة: ${printer.name}');
        return false;
      }
    } catch (e) {
      debugPrint('خطأ في إضافة الطابعة المخصصة: $e');
      return false;
    }
  }

  /// تحديد الطابعة المحددة
  void setSelectedPrinter(PrinterInfo printer) {
    _selectedPrinter = printer;
    debugPrint('تم تحديد الطابعة: ${printer.name}');
  }

  /// الحصول على الطابعة المحددة
  PrinterInfo? get selectedPrinter => _selectedPrinter;

  /// الحصول على قائمة الطابعات المكتشفة
  List<PrinterInfo> get discoveredPrinters =>
      List.unmodifiable(_discoveredPrinters);
}

/// معلومات الطابعة
class PrinterInfo {
  final String name;
  final PrinterType type;
  final String connectionString;
  final bool isDefault;
  final bool isAvailable;
  final Map<String, dynamic> details;

  PrinterInfo({
    required this.name,
    required this.type,
    required this.connectionString,
    this.isDefault = false,
    this.isAvailable = true,
    this.details = const {},
  });

  @override
  String toString() {
    return 'PrinterInfo(name: $name, type: $type, available: $isAvailable)';
  }
}
