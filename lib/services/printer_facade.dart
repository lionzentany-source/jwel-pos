import 'package:flutter/foundation.dart';
// احتفظنا فقط بالمستعمل فعلياً: Uint8List و debugPrint
import '../models/invoice.dart';
import '../models/cart_item.dart';
import '../models/invoice_render_data.dart';
import '../services/print_service_new.dart';
import '../services/real_printer_service.dart';
import '../services/enhanced_printer_service.dart';
import '../repositories/settings_repository.dart';
import '../services/user_activity_service.dart';
import '../models/user_activity.dart';

/// أوضاع الطباعة المتاحة
enum InvoicePrintMode { thermal, html, pdfSystem, enhanced }

/// واجهة موحدة لطباعة الفواتير
class PrinterFacade {
  final PrintServiceNew _bluetoothService;
  final RealPrinterService _systemPrinterService;
  final EnhancedPrinterService _enhancedPrinterService;
  final SettingsRepository _settingsRepository;
  final UserActivityService _activityService;

  PrinterFacade({
    PrintServiceNew? bluetooth,
    RealPrinterService? system,
    EnhancedPrinterService? enhanced,
    SettingsRepository? settingsRepository,
    UserActivityService? activityService,
  }) : _bluetoothService = bluetooth ?? PrintServiceNew(),
       _systemPrinterService = system ?? RealPrinterService(),
       _enhancedPrinterService = enhanced ?? EnhancedPrinterService(),
       _settingsRepository = settingsRepository ?? SettingsRepository(),
       _activityService = activityService ?? UserActivityService();

  Future<InvoiceRenderData> buildRenderData({
    required Invoice invoice,
    required List<CartItem> items,
    String? customerName,
    String? cashierName,
    bool showLogo = true,
    String? footerText,
  }) async {
    final storeName = await _settingsRepository.getStoreName() ?? 'متجر';
    final storeAddress = await _settingsRepository.getStoreAddress();
    final storePhone = await _settingsRepository.getStorePhone();
    final footer = footerText ?? await _settingsRepository.getInvoiceFooter();
    return InvoiceRenderData.fromModels(
      invoice: invoice,
      items: items,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      customerName: customerName,
      cashierName: cashierName,
      showLogo: showLogo,
      footerText: footer,
    );
  }

  Future<bool> printInvoice({
    required Invoice invoice,
    required List<CartItem> items,
    required InvoicePrintMode mode,
    String? customerName,
    String? cashierName,
    bool showLogo = true,
    String? footerText,
  }) async {
    final data = await buildRenderData(
      invoice: invoice,
      items: items,
      customerName: customerName,
      cashierName: cashierName,
      showLogo: showLogo,
      footerText: footerText,
    );

    bool success = false;
    String modeName = mode.name;

    try {
      switch (mode) {
        case InvoicePrintMode.thermal:
          final bytes = await _bluetoothService.generateThermalReceipt(data);
          await _bluetoothService.printBluetooth(Uint8List.fromList(bytes));
          success = true;
          break;
        case InvoicePrintMode.html:
          await _bluetoothService.printInvoiceHTMLFromData(
            data,
          ); // يستخدم HTML موحد
          success = true;
          break;
        case InvoicePrintMode.pdfSystem:
          final printer = await _systemPrinterService.getDefaultPrinter();
          if (printer == null) throw Exception('لا توجد طابعة نظام متاحة');
          success = await _systemPrinterService.printInvoice(printer, {
            'storeName': data.storeName,
            'invoiceNumber': data.invoiceNumber,
            'items': data.items
                .map(
                  (ci) => {
                    'name': ci.item.sku,
                    'quantity': ci.quantity,
                    'price': ci.unitPrice,
                    'total': ci.totalPrice,
                  },
                )
                .toList(),
            'subtotal': data.subtotal,
            'tax': data.tax,
            'total': data.total,
          });
          break;
        case InvoicePrintMode.enhanced:
          final selected = _enhancedPrinterService.selectedPrinter;
          if (selected == null) {
            throw Exception('لم يتم اختيار طابعة محسّنة');
          }
          success = await _enhancedPrinterService.printInvoice(selected, {
            'storeName': data.storeName,
            'invoiceNumber': data.invoiceNumber,
            'items': data.items
                .map(
                  (ci) => {
                    'name': ci.item.sku,
                    'quantity': ci.quantity,
                    'price': ci.unitPrice,
                    'total': ci.totalPrice,
                  },
                )
                .toList(),
            'subtotal': data.subtotal,
            'discount': data.discount,
            'tax': data.tax,
            'total': data.total,
            'paymentMethod': data.paymentMethod,
          });
          break;
      }
      await _logActivity(
        ActivityType.printInvoice,
        'طباعة فاتورة ($modeName) رقم ${data.invoiceNumber}',
        success: success,
      );
      return success;
    } catch (e) {
      debugPrint('خطأ في طباعة الفاتورة: $e');
      await _logActivity(
        ActivityType.printInvoice,
        'فشل طباعة فاتورة ($modeName) رقم ${data.invoiceNumber}: $e',
        success: false,
      );
      rethrow;
    }
  }

  Future<void> _logActivity(
    ActivityType type,
    String description, {
    required bool success,
  }) async {
    try {
      // مستخدم افتراضي (يمكن دمجه مع UserService لاحقاً)
      await _activityService.logActivity(
        userId: 0,
        username: 'system',
        activityType: type,
        description: description + (success ? ' ✅' : ' ❌'),
      );
    } catch (_) {}
  }
}
