import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../services/print_service_new.dart';
import '../models/invoice.dart';
import '../models/cart_item.dart';
import '../models/printer_settings.dart';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// مزود خدمة الطباعة
final printServiceProvider = Provider<PrintServiceNew>((ref) {
  return PrintServiceNew();
});

// مزود حالة الطباعة
final printNotifierProvider =
    StateNotifierProvider<PrintNotifier, AsyncValue<bool>>((ref) {
      final printService = ref.read(printServiceProvider);
      return PrintNotifier(printService);
    });

// مزود إعدادات الطابعة
final printerSettingsProvider =
    StateNotifierProvider<
      PrinterSettingsNotifier,
      AsyncValue<PrinterSettings?>
    >((ref) {
      final printService = ref.read(printServiceProvider);
      return PrinterSettingsNotifier(printService);
    });

class PrintNotifier extends StateNotifier<AsyncValue<bool>> {
  PrintNotifier(this._printService) : super(const AsyncValue.data(false));

  final PrintServiceNew _printService;

  // طباعة فاتورة PDF
  Future<void> printInvoicePDF(Invoice invoice, List<CartItem> items) async {
    state = const AsyncValue.loading();
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text('Invoice: ${invoice.invoiceNumber}'),
                pw.Text('Total: ${invoice.total}'),
                pw.Header(level: 0, text: 'Items'),
                for (var item in items)
                  pw.Text('${item.name} x ${item.quantity} = ${item.price}'),
              ],
            );
          },
        ),
      );

      final Uint8List pdfBytes = await pdf.save();
      // Assuming USB printer for PDF printing
      // You might need to select the correct USB device here
      // For now, this is a placeholder for actual printing logic
      // await _printService.printUsb(pdfBytes);
      state = const AsyncValue.data(true);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // طباعة فاتورة حرارية
  Future<void> printInvoiceThermal(Invoice invoice, List<CartItem> items) async {
    state = const AsyncValue.loading();
    try {
      List<String> thermalItems = [];
      thermalItems.add('Invoice: ${invoice.invoiceNumber}');
      thermalItems.add('Total: ${invoice.total}');
      thermalItems.add('-- Items --');
      for (var item in items) {
        thermalItems.add('${item.name} x ${item.quantity} = ${item.price}');
      }

      final List<int> bytes = await _printService.generateThermalReceipt(thermalItems);
      // Assuming Bluetooth printer for thermal printing
      // You might need to select the correct Bluetooth device here
      // For now, this is a placeholder for actual printing logic
      // await _printService.printBluetooth(Uint8List.fromList(bytes));
      state = const AsyncValue.data(true);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // Connect to a Bluetooth device
  Future<void> connectBluetooth(BluetoothDevice device) async {
    state = const AsyncValue.loading();
    try {
      final success = await _printService.connectBluetooth(device);
      state = AsyncValue.data(success);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // Disconnect from Bluetooth device
  Future<void> disconnectBluetooth() async {
    state = const AsyncValue.loading();
    try {
      final success = await _printService.disconnectBluetooth();
      state = AsyncValue.data(success);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // Connect to a USB device
  Future<void> connectUsb(UsbDevice device) async {
    state = const AsyncValue.loading();
    try {
      final success = await _printService.connectUsb(device);
      state = AsyncValue.data(success);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // Disconnect from USB device
  Future<void> disconnectUsb() async {
    state = const AsyncValue.loading();
    try {
      final success = await _printService.disconnectUsb();
      state = AsyncValue.data(success);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // Test printer connection
  Future<void> testPrinter(PrinterSettings settings) async {
    state = const AsyncValue.loading();
    try {
      if (settings.type == PrinterType.bluetooth && settings.address != null) {
        // For testing, we'll just try to connect and disconnect
        // In a real scenario, you'd send a test print command
        final devices = await _printService.bluetoothDevices.first;
        final device = devices.firstWhere((d) => d.address == settings.address);
        final connected = await _printService.connectBluetooth(device);
        if (connected) {
          await _printService.disconnectBluetooth();
          state = const AsyncValue.data(true);
        } else {
          state = const AsyncValue.data(false);
        }
      } else if (settings.type == PrinterType.usb && settings.vendorId != null && settings.productId != null) {
        // For testing, we'll just try to connect and disconnect
        // In a real scenario, you'd send a test print command
        final devices = await _printService.getUsbDevices();
        final device = devices.firstWhere((d) => d.vendorId == settings.vendorId && d.productId == settings.productId);
        final connected = await _printService.connectUsb(device);
        if (connected) {
          await _printService.disconnectUsb();
          state = const AsyncValue.data(true);
        } else {
          state = const AsyncValue.data(false);
        }
      } else {
        state = const AsyncValue.data(false);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // إعادة تعيين الحالة
  void resetState() {
    state = const AsyncValue.data(false);
  }
}

class PrinterSettingsNotifier
    extends StateNotifier<AsyncValue<PrinterSettings?>> {
  PrinterSettingsNotifier(this._printService)
    : super(const AsyncValue.loading()) {
    _loadPrinterSettings();
  }

  final PrintServiceNew _printService;

  Future<void> _loadPrinterSettings() async {
    try {
      // سيتم تحميل الإعدادات من قاعدة البيانات لاحقاً
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // حفظ إعدادات الطابعة
  Future<void> savePrinterSettings(PrinterSettings settings) async {
    try {
      // This is a placeholder. In a real app, you'd save these settings
      // to persistent storage (e.g., SharedPreferences, database).
      state = AsyncValue.data(settings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // حذف إعدادات الطابعة
  Future<void> removePrinterSettings() async {
    try {
      // يمكن إضافة منطق حذف الإعدادات هنا
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
