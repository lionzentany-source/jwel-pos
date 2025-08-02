import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/print_service_new.dart';
import '../services/printer_facade.dart';
import '../models/invoice.dart';
import '../models/cart_item.dart';
import '../models/printer_settings.dart';
import '../repositories/settings_repository.dart';
import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';

// مزود خدمة الطباعة
final printServiceProvider = Provider<PrintServiceNew>((ref) {
  return PrintServiceNew();
});

// مزود حالة الطباعة
final printNotifierProvider =
    StateNotifierProvider<PrintNotifier, AsyncValue<bool>>((ref) {
      final printService = ref.read(printServiceProvider);
      return PrintNotifier(printService, ref);
    });

// مزود الواجهة الموحدة للطباعة
final printerFacadeProvider = Provider<PrinterFacade>((ref) => PrinterFacade());

// مزود إعدادات الطابعة
final printerSettingsProvider =
    StateNotifierProvider<
      PrinterSettingsNotifier,
      AsyncValue<PrinterSettings?>
    >((ref) {
      return PrinterSettingsNotifier();
    });

class PrintNotifier extends StateNotifier<AsyncValue<bool>> {
  PrintNotifier(this._printService, this._ref)
    : super(const AsyncValue.data(false));
  final PrintServiceNew _printService;
  final Ref _ref;

  // طباعة HTML عبر الواجهة الموحدة (احتفاظ بالاسم القديم للتوافق)
  Future<void> printInvoicePDF(Invoice invoice, List<CartItem> items) async {
    state = const AsyncValue.loading();
    try {
      final facade = _ref.read(printerFacadeProvider);
      await facade.printInvoice(
        invoice: invoice,
        items: items,
        mode: InvoicePrintMode.html,
      );
      state = const AsyncValue.data(true);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // طباعة حرارية عبر الواجهة الموحدة
  Future<void> printInvoiceThermal(
    Invoice invoice,
    List<CartItem> items,
  ) async {
    state = const AsyncValue.loading();
    try {
      final facade = _ref.read(printerFacadeProvider);
      await facade.printInvoice(
        invoice: invoice,
        items: items,
        mode: InvoicePrintMode.thermal,
      );
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

  // اختبار الطابعة (بلوتوث فقط)
  Future<void> testPrinter(PrinterSettings settings) async {
    state = const AsyncValue.loading();
    try {
      if (settings.type == PrinterType.bluetooth) {
        final devices = await _printService.bluetoothDevices.first;
        final device = devices.firstWhere(
          (d) => d.address == settings.address,
          orElse: () => throw Exception("Device not found"),
        );
        final connected = await _printService.connectBluetooth(device);
        if (connected) {
          await _printService.disconnectBluetooth();
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
  final SettingsRepository _settingsRepository;
  PrinterSettingsNotifier({SettingsRepository? settingsRepository})
    : _settingsRepository = settingsRepository ?? SettingsRepository(),
      super(const AsyncValue.loading()) {
    _loadPrinterSettings();
  }

  Future<void> _loadPrinterSettings() async {
    try {
      final stored = await _settingsRepository.getDefaultPrinterSettings();
      state = AsyncValue.data(stored);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> savePrinterSettings(PrinterSettings settings) async {
    try {
      await _settingsRepository.setDefaultPrinterSettings(settings);
      state = AsyncValue.data(settings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> removePrinterSettings() async {
    try {
      await _settingsRepository.setDefaultPrinterSettings(
        PrinterSettings(name: '', address: '', type: PrinterType.thermal),
      );
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
