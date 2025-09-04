import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import '../models/invoice.dart';
import '../models/cart_item.dart';
import '../models/item.dart';
import '../services/printer_facade.dart';
import '../providers/print_provider.dart';
import '../models/printer_settings.dart';

class PrintPreviewScreen extends ConsumerStatefulWidget {
  const PrintPreviewScreen({super.key});

  @override
  ConsumerState<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends ConsumerState<PrintPreviewScreen> {
  // إعدادات الفاتورة القابلة للتعديل
  String storeName = 'متجر الجوهر';
  String storeAddress = 'شارع الجوهر، المدينة';
  String storePhone = '+966 50 123 4567';
  bool showLogo = true;
  bool showTax = true;
  bool showDiscount = true;
  String footerText = 'شكراً لزيارتكم';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xfff6f8fa), // خلفية موحدة
      child: AdaptiveScaffold(
        title: 'معاينة الطباعة',
        body: Row(
          children: [
            // جانب التحكم
            Expanded(flex: 2, child: _buildControlPanel()),

            // خط فاصل
            Container(width: 1, color: Color(0xffe5e7eb)),

            // جانب المعاينة
            Expanded(flex: 3, child: _buildPreviewPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إعدادات الفاتورة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _buildSection('معلومات المتجر', [
              _buildTextField('اسم المتجر', storeName, (value) {
                setState(() => storeName = value);
              }),
              _buildTextField('عنوان المتجر', storeAddress, (value) {
                setState(() => storeAddress = value);
              }),
              _buildTextField('هاتف المتجر', storePhone, (value) {
                setState(() => storePhone = value);
              }),
            ]),

            _buildSection('خيارات العرض', [
              _buildSwitch('إظهار الشعار', showLogo, (value) {
                setState(() => showLogo = value);
              }),
              _buildSwitch('إظهار الضريبة', showTax, (value) {
                setState(() => showTax = value);
              }),
              _buildSwitch('إظهار الخصم', showDiscount, (value) {
                setState(() => showDiscount = value);
              }),
            ]),

            _buildSection('نص التذييل', [
              _buildTextField('نص التذييل', footerText, (value) {
                setState(() => footerText = value);
              }),
            ]),

            const SizedBox(height: 30),

            // أزرار الإجراءات
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _saveSettings,
                child: const Text('حفظ الإعدادات'),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: CupertinoColors.systemGreen,
                onPressed: _testPrint,
                child: const Text('طباعة تجريبية'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'معاينة الفاتورة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: Center(
              child: Container(
                // محاكاة عرض ورق حراري 80mm (نحو 302px عند 96dpi تقريبياً)
                width: 300,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  border: Border.all(color: CupertinoColors.separator),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildInvoicePreview(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicePreview() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // شعار المتجر
          if (showLogo) ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                CupertinoIcons.building_2_fill,
                size: 40,
                color: CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // معلومات المتجر
          Text(
            storeName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            storeAddress,
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          Text(
            storePhone,
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // خط فاصل
          Container(height: 1, color: CupertinoColors.separator),

          const SizedBox(height: 16),

          // معلومات الفاتورة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'رقم الفاتورة: #001',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.black,
                ),
              ),
              Text(
                'التاريخ: ${DateTime.now().toString().split(' ')[0]}',
                style: const TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // جدول الأصناف
          _buildItemsTable(),

          const SizedBox(height: 20),

          // المجاميع
          _buildTotalsSection(),

          const SizedBox(height: 20),

          // نص التذييل
          if (footerText.isNotEmpty) ...[
            Container(height: 1, color: CupertinoColors.separator),
            const SizedBox(height: 16),
            Text(
              footerText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Column(
      children: [
        // رأس الجدول
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: CupertinoColors.separator),
            ),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'الصنف',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'الكمية',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'السعر',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),

        // الأصناف التجريبية
        _buildItemRow('خاتم ذهب 18 قيراط', '1', '2,500.00'),
        _buildItemRow('سوار فضة', '1', '850.00'),
        _buildItemRow('قلادة ذهب', '1', '3,200.00'),
      ],
    );
  }

  Widget _buildItemRow(String name, String quantity, String price) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name)),
          Expanded(flex: 1, child: Text(quantity, textAlign: TextAlign.center)),
          Expanded(
            flex: 2,
            child: Text('$price د.ل', textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Column(
      children: [
        _buildTotalRow('المجموع الفرعي', '6,550.00'),
        if (showDiscount) _buildTotalRow('الخصم', '-100.00'),
        if (showTax) _buildTotalRow('الضريبة (15%)', '967.50'),
        Container(
          height: 1,
          color: CupertinoColors.separator,
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        _buildTotalRow('الإجمالي', '7,417.50', isTotal: true),
      ],
    );
  }

  Widget _buildTotalRow(String label, String amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: CupertinoColors.black,
            ),
          ),
          Text(
            '$amount د.ل',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal
                  ? CupertinoColors.activeGreen
                  : CupertinoColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.activeBlue,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: TextEditingController(text: value),
          onChanged: onChanged,
          padding: const EdgeInsets.all(12),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  void _saveSettings() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('حفظ الإعدادات'),
        content: const Text('تم حفظ إعدادات الطباعة بنجاح'),
        actions: [
          CupertinoDialogAction(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _testPrint() {
    // إنشاء بيانات فاتورة تجريبية صغيرة
    final invoice = Invoice(
      invoiceNumber: 'TEST-0001',
      subtotal: 6500,
      discount: showDiscount ? 100 : 0,
      tax: showTax ? 967.5 : 0,
      total: showTax ? 7417.5 : (6500 - (showDiscount ? 100 : 0)),
      paymentMethod: PaymentMethod.cash,
      userId: 0,
    );

    final dummyItems = <CartItem>[
      CartItem(
        item: Item(
          id: 1,
          sku: 'RING18K',
          categoryId: 0,
          materialId: 0,
          weightGrams: 10,
          karat: 18,
          workmanshipFee: 500,
        ),
        unitPrice: 2500,
      ),
      CartItem(
        item: Item(
          id: 2,
          sku: 'SILV-BRACE',
          categoryId: 0,
          materialId: 0,
          weightGrams: 20,
          karat: 0,
          workmanshipFee: 150,
          stonePrice: 0,
        ),
        unitPrice: 850,
      ),
      CartItem(
        item: Item(
          id: 3,
          sku: 'NECK-GOLD',
          categoryId: 0,
          materialId: 0,
          weightGrams: 25,
          karat: 18,
          workmanshipFee: 600,
        ),
        unitPrice: 3200,
      ),
    ];

    final facade = ref.read(printerFacadeProvider);

    // اختيار وضع الطباعة حسب نوع الطابعة المحفوظة إن وجد
    final settingsAsync = ref.read(printerSettingsProvider);
    InvoicePrintMode mode = InvoicePrintMode.html; // افتراضي
    settingsAsync.whenData((settings) {
      if (settings != null) {
        switch (settings.type) {
          case PrinterType.bluetooth:
          case PrinterType.thermal:
            mode = InvoicePrintMode.thermal;
            break;
          case PrinterType.windows:
            mode = InvoicePrintMode.pdfSystem;
            break;
          case PrinterType.network:
          case PrinterType.usb:
            mode = InvoicePrintMode.enhanced;
            break;
        }
      }
    });

    facade
        .printInvoice(
          invoice: invoice,
          items: dummyItems,
          mode: mode,
          customerName: 'عميل تجريبي',
          cashierName: 'اختبار',
          showLogo: showLogo,
          footerText: footerText,
        )
        .then((_) {
          if (!mounted) return;
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('طباعة تجريبية'),
              content: Text('تم إرسال المعاينة للطابعة (${mode.name}).'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('موافق'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        })
        .catchError((e) {
          if (!mounted) return;
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('خطأ'),
              content: Text('فشل الطباعة: $e'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('موافق'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        });
  }
}
