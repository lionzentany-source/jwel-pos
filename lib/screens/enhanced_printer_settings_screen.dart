import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:collection/collection.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/app_button.dart';
import '../services/enhanced_printer_service.dart';
import '../models/printer_settings.dart';
import '../models/invoice_render_data.dart';
import '../models/cart_item.dart';
import '../models/item.dart';

class EnhancedPrinterSettingsScreen extends ConsumerStatefulWidget {
  const EnhancedPrinterSettingsScreen({super.key});

  @override
  ConsumerState<EnhancedPrinterSettingsScreen> createState() =>
      _EnhancedPrinterSettingsScreenState();
}

class _EnhancedPrinterSettingsScreenState
    extends ConsumerState<EnhancedPrinterSettingsScreen> {
  final _printerService = EnhancedPrinterService();

  List<PrinterInfo> _printers = [];
  PrinterInfo? _selectedPrinter;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _cancelDiscovery = false;

  // إعدادات الطابعة المخصصة
  final _customNameController = TextEditingController();
  final _customIpController = TextEditingController();
  final _customPortController = TextEditingController(text: '9100');
  final _customDeviceIdController = TextEditingController();
  PrinterType _customType = PrinterType.network;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _customNameController.dispose();
    _customIpController.dispose();
    _customPortController.dispose();
    _customDeviceIdController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final initialized = await _printerService.initialize();
      if (!mounted) return;

      if (initialized) {
        await _discoverPrinters();
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      } else {
        _showError(
          'فشل في تهيئة خدمة الطباعة',
          'تأكد من وجود أداة الطباعة الصينية',
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('خطأ في التهيئة', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _discoverPrinters() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _cancelDiscovery = false;
      // Run discovery with a safety timeout so UI never hangs forever
      final printers = await _printerService.discoverPrinters().timeout(
        const Duration(seconds: 12),
        onTimeout: () => [],
      );
      if (!mounted) return;
      if (_cancelDiscovery) return; // user cancelled
      setState(() {
        _printers = printers;
        _loadSelectedPrinter();
        _selectedPrinter ??=
            _printerService.selectedPrinter ??
            printers.where((p) => p.isDefault).firstOrNull ??
            printers.firstOrNull;
        if (_selectedPrinter != null) {
          _printerService.setSelectedPrinter(_selectedPrinter!);
        }
      });
    } catch (e) {
      if (mounted) {
        _showError('خطأ في اكتشاف الطابعات', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSelectedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final printerName = prefs.getString('selected_printer_name');
    if (printerName != null) {
      final printer = _printers.firstWhereOrNull((p) => p.name == printerName);
      if (printer != null) {
        setState(() {
          _selectedPrinter = printer;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8FA),
      child: AdaptiveScaffold(
        title: 'إعدادات الطباعة المتقدمة',
        showBackButton: true,
        body: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : !_isInitialized
            ? _buildInitializationError()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDiscoverySection(),
                    const SizedBox(height: 20),
                    _buildPrintersListSection(),
                    const SizedBox(height: 20),
                    _buildSelectedPrinterSection(),
                    const SizedBox(height: 20),
                    _buildCustomPrinterSection(),
                    const SizedBox(height: 20),
                    _buildTestSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInitializationError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 64,
            color: CupertinoColors.systemRed,
          ),
          const SizedBox(height: 16),
          const Text(
            'فشل في تهيئة خدمة الطباعة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'تأكد من وجود أداة الطباعة الصينية في مجلد التطبيق',
            textAlign: TextAlign.center,
            style: TextStyle(color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 20),
          AppButton.primary(
            text: 'إعادة المحاولة',
            onPressed: _initializeService,
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: m.Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: m.Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'اكتشاف الطابعات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Text(
                'تم العثور على ${_printers.length} طابعة',
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              text: _isLoading ? 'جارٍ البحث...' : 'إعادة البحث',
              onPressed: _isLoading
                  ? null
                  : () async {
                      await _discoverPrinters();
                    },
            ),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppButton.secondary(
                text: 'إلغاء البحث',
                onPressed: () {
                  // best-effort cancel: set flag and stop showing loader
                  setState(() {
                    _cancelDiscovery = true;
                    _isLoading = false;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrintersListSection() {
    if (_printers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: m.Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: m.Colors.black.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(
              CupertinoIcons.printer,
              size: 48,
              color: CupertinoColors.systemGrey3,
            ),
            SizedBox(height: 16),
            Text(
              'لم يتم العثور على طابعات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'تأكد من تشغيل الطابعة وتوصيلها بالكمبيوتر',
              textAlign: TextAlign.center,
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: m.Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: m.Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الطابعات المتاحة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...List.generate(_printers.length, (index) {
            final printer = _printers[index];
            return _buildPrinterTile(printer);
          }),
        ],
      ),
    );
  }

  Widget _buildPrinterTile(PrinterInfo printer) {
    final isSelected = _selectedPrinter == printer;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? CupertinoColors.activeBlue.withValues(alpha: 0.1)
            : CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: CupertinoColors.activeBlue, width: 2)
            : null,
      ),
      child: CupertinoListTile(
        leading: Icon(
          _getPrinterIcon(printer.type),
          color: _getPrinterColor(printer.type),
          size: 24,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                printer.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (printer.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CupertinoColors.activeGreen,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'افتراضية',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getPrinterTypeText(printer.type),
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              printer.isAvailable ? 'متاح' : 'غير متاح',
              style: TextStyle(
                fontSize: 12,
                color: printer.isAvailable
                    ? CupertinoColors.activeGreen
                    : CupertinoColors.systemRed,
              ),
            ),
          ],
        ),
        onTap: () {
          setState(() {
            _selectedPrinter = printer;
            _printerService.setSelectedPrinter(printer);
          });
        },
      ),
    );
  }

  Widget _buildSelectedPrinterSection() {
    if (_selectedPrinter == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: m.Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: m.Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفاصيل الطابعة المحددة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('الاسم', _selectedPrinter!.name),
          _buildDetailRow('النوع', _getPrinterTypeText(_selectedPrinter!.type)),
          _buildDetailRow('طريقة الاتصال', _selectedPrinter!.connectionString),
          _buildDetailRow(
            'الحالة',
            _selectedPrinter!.isAvailable ? 'متاح' : 'غير متاح',
          ),
          if (_selectedPrinter!.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'تفاصيل إضافية:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            ..._selectedPrinter!.details.entries.map(
              (entry) => _buildDetailRow(entry.key, entry.value.toString()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomPrinterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: m.Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: m.Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إضافة طابعة مخصصة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // نوع الطابعة
          const Text(
            'نوع الطابعة',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<PrinterType>(
            groupValue: _customType,
            children: const {
              PrinterType.network: Text('شبكة', style: TextStyle(fontSize: 12)),
              PrinterType.usb: Text('USB', style: TextStyle(fontSize: 12)),
              PrinterType.bluetooth: Text(
                'بلوتوث',
                style: TextStyle(fontSize: 12),
              ),
              PrinterType.windows: Text(
                'Windows',
                style: TextStyle(fontSize: 12),
              ),
            },
            onValueChanged: (value) {
              setState(() {
                _customType = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // اسم الطابعة
          const Text(
            'اسم الطابعة',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _customNameController,
            placeholder: 'أدخل اسم الطابعة',
            padding: const EdgeInsets.all(12),
          ),
          const SizedBox(height: 16),

          // إعدادات حسب النوع
          ..._buildCustomTypeSettings(),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              text: 'إضافة الطابعة',
              onPressed: _addCustomPrinter,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCustomTypeSettings() {
    switch (_customType) {
      case PrinterType.network:
        return [
          const Text('عنوان IP', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _customIpController,
            placeholder: '192.168.1.100',
            keyboardType: TextInputType.number,
            padding: const EdgeInsets.all(12),
          ),
          const SizedBox(height: 12),
          const Text('المنفذ', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _customPortController,
            placeholder: '9100',
            keyboardType: TextInputType.number,
            padding: const EdgeInsets.all(12),
          ),
        ];
      case PrinterType.usb:
      case PrinterType.bluetooth:
        return [
          const Text(
            'معرف الجهاز',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _customDeviceIdController,
            placeholder: 'أدخل معرف الجهاز',
            padding: const EdgeInsets.all(12),
          ),
        ];
      case PrinterType.windows:
      case PrinterType.thermal:
        return [
          const Text(
            'سيتم استخدام اسم الطابعة كما هو مثبت في Windows',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel,
              fontSize: 14,
            ),
          ),
        ];
    }
  }

  Widget _buildTestSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: m.Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: m.Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختبار الطباعة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton.primary(
                  text: 'اختبار الطباعة',
                  onPressed: _selectedPrinter != null && !_isLoading
                      ? _testPrint
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton.secondary(
                  text: 'طباعة فاتورة تجريبية',
                  onPressed: _selectedPrinter != null && !_isLoading
                      ? _testInvoicePrint
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              text: 'حفظ الإعدادات',
              onPressed: _selectedPrinter != null ? _saveSettings : null,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPrinterIcon(PrinterType type) {
    switch (type) {
      case PrinterType.usb:
        return CupertinoIcons.device_desktop;
      case PrinterType.network:
        return CupertinoIcons.wifi;
      case PrinterType.bluetooth:
        return CupertinoIcons.bluetooth;
      case PrinterType.windows:
        return CupertinoIcons.printer;
      case PrinterType.thermal:
        return CupertinoIcons.printer_fill;
    }
  }

  Color _getPrinterColor(PrinterType type) {
    switch (type) {
      case PrinterType.usb:
        return CupertinoColors.activeBlue;
      case PrinterType.network:
        return CupertinoColors.activeGreen;
      case PrinterType.bluetooth:
        return CupertinoColors.systemPurple;
      case PrinterType.windows:
        return CupertinoColors.systemOrange;
      case PrinterType.thermal:
        return CupertinoColors.systemRed;
    }
  }

  String _getPrinterTypeText(PrinterType type) {
    switch (type) {
      case PrinterType.usb:
        return 'طابعة USB';
      case PrinterType.network:
        return 'طابعة شبكة';
      case PrinterType.bluetooth:
        return 'طابعة بلوتوث';
      case PrinterType.windows:
        return 'طابعة Windows';
      case PrinterType.thermal:
        return 'طابعة حرارية';
    }
  }

  Future<void> _addCustomPrinter() async {
    if (_customNameController.text.isEmpty) {
      _showError('خطأ', 'يرجى إدخال اسم الطابعة');
      return;
    }

    String connectionString = '';
    switch (_customType) {
      case PrinterType.network:
        if (_customIpController.text.isEmpty ||
            _customPortController.text.isEmpty) {
          _showError('خطأ', 'يرجى إدخال عنوان IP والمنفذ');
          return;
        }
        connectionString =
            '${_customIpController.text}:${_customPortController.text}';
        break;
      case PrinterType.usb:
      case PrinterType.bluetooth:
        if (_customDeviceIdController.text.isEmpty) {
          _showError('خطأ', 'يرجى إدخال معرف الجهاز');
          return;
        }
        connectionString = _customDeviceIdController.text;
        break;
      case PrinterType.windows:
      case PrinterType.thermal:
        connectionString = _customNameController.text;
        break;
    }

    setState(() => _isLoading = true);

    try {
      final printer = PrinterInfo(
        name: _customNameController.text,
        type: _customType,
        connectionString: connectionString,
      );

      final success = await _printerService.addCustomPrinter(printer);
      if (success) {
        await _discoverPrinters();
        _clearCustomForm();
        _showMessage('نجح', 'تم إضافة الطابعة بنجاح');
      } else {
        _showError('فشل', 'لم يتم إضافة الطابعة. تحقق من الإعدادات');
      }
    } catch (e) {
      _showError('خطأ', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearCustomForm() {
    _customNameController.clear();
    _customIpController.clear();
    _customPortController.text = '9100';
    _customDeviceIdController.clear();
    _customType = PrinterType.network;
  }

  Future<void> _testPrint() async {
    if (_selectedPrinter == null) return;

    setState(() => _isLoading = true);

    try {
      final success = await _printerService.testPrint(_selectedPrinter!);
      if (success) {
        _showMessage('نجح الاختبار', 'تم إرسال صفحة الاختبار للطابعة بنجاح');
      } else {
        _showError('فشل الاختبار', 'لم يتم طباعة صفحة الاختبار');
      }
    } catch (e) {
      _showError('خطأ في الاختبار', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testInvoicePrint() async {
    if (_selectedPrinter == null) return;

    setState(() => _isLoading = true);

    try {
      final testInvoiceData = InvoiceRenderData(
        storeName: 'متجر الجوهر للمجوهرات',
        storeAddress: 'شارع الجوهر، المدينة',
        storePhone: '+218-91-1234567',
        invoiceNumber: 'TEST-001',
        customerName: 'عميل تجريبي',
        items: [
          CartItem(
            item: Item(
              sku: 'خاتم ذهب 18 قيراط',
              categoryId: 1,
              materialId: 1,
              weightGrams: 10,
              karat: 18,
              workmanshipFee: 500,
              costPrice: 2000,
            ),
            quantity: 1,
            unitPrice: 250,
          ),
          CartItem(
            item: Item(
              sku: 'سلسلة فضة',
              categoryId: 2,
              materialId: 2,
              weightGrams: 20,
              karat: 0,
              workmanshipFee: 100,
              costPrice: 50,
            ),
            quantity: 2,
            unitPrice: 75,
          ),
        ],
        subtotal: 400.0,
        discount: 20.0,
        tax: 0.0,
        total: 380.0,
        paymentMethod: 'نقدي',
        date: DateTime.now(),
      );

      final success = await _printerService.printInvoice(
        _selectedPrinter!,
        testInvoiceData,
      );
      if (success) {
        _showMessage('نجح الاختبار', 'تم طباعة الفاتورة التجريبية بنجاح');
      } else {
        _showError('فشل الاختبار', 'لم يتم طباعة الفاتورة التجريبية');
      }
    } catch (e) {
      _showError('خطأ في الاختبار', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _saveSettings() async {
    if (_selectedPrinter == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_name', _selectedPrinter!.name);

    _showMessage(
      'تم الحفظ',
      'تم حفظ إعدادات الطابعة بنجاح\n\nالطابعة المحددة: ${_selectedPrinter!.name}',
    );
  }

  void _showMessage(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showError(String title, String error) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(error),
        actions: [
          CupertinoDialogAction(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
