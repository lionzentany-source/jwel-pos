import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/adaptive_scaffold.dart';
import '../models/invoice.dart';
import '../models/customer.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/print_provider.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/customer_repository.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _discountController = TextEditingController();

  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  // Customer? _selectedCustomer; // للاستخدام المستقبلي في اختيار العميل
  bool _isProcessing = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final currency = ref.watch(currencyProvider);

    return AdaptiveScaffold(
      title: 'إتمام البيع',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ملخص الطلب
            _buildOrderSummary(cart, currency),

            const SizedBox(height: 20),

            // معلومات العميل
            _buildCustomerSection(),

            const SizedBox(height: 20),

            // طريقة الدفع
            _buildPaymentMethodSection(),

            const SizedBox(height: 20),

            // خصم إضافي
            _buildDiscountSection(currency),

            const SizedBox(height: 20),

            // ملاحظات
            _buildNotesSection(),

            const SizedBox(height: 30),

            // أزرار الإجراء
            _buildActionButtons(cart),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(cart, AsyncValue<String> currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص الطلب',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...cart.items.map(
            (cartItem) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${cartItem.item.sku} (${cartItem.quantity}x)',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  currency.when(
                    data: (curr) => Text(
                      '${cartItem.totalPrice.toStringAsFixed(2)} $curr',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    loading: () => const Text('...'),
                    error: (_, __) => const Text('خطأ'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Container(height: 1, color: CupertinoColors.separator),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الإجمالي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              currency.when(
                data: (curr) => Text(
                  '${cart.total.toStringAsFixed(2)} $curr',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.activeGreen,
                  ),
                ),
                loading: () => const Text('...'),
                error: (_, __) => const Text('خطأ'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'معلومات العميل (اختياري)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: _customerNameController,
            placeholder: 'اسم العميل',
            padding: const EdgeInsets.all(12),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _customerPhoneController,
            placeholder: 'رقم الهاتف',
            keyboardType: TextInputType.phone,
            padding: const EdgeInsets.all(12),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'طريقة الدفع',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...PaymentMethod.values.map(
            (method) => CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _selectedPaymentMethod = method;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _selectedPaymentMethod == method
                      ? CupertinoColors.activeBlue.withValues(alpha: 0.1)
                      : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedPaymentMethod == method
                        ? CupertinoColors.activeBlue
                        : CupertinoColors.systemGrey4,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedPaymentMethod == method
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.circle,
                      color: _selectedPaymentMethod == method
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.systemGrey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      method.displayName,
                      style: TextStyle(
                        color: _selectedPaymentMethod == method
                            ? CupertinoColors.activeBlue
                            : CupertinoColors.label,
                        fontWeight: _selectedPaymentMethod == method
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountSection(AsyncValue<String> currency) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'خصم إضافي',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: _discountController,
            placeholder: 'قيمة الخصم',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: currency.when(
              data: (curr) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(curr),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            padding: const EdgeInsets.all(12),
            onChanged: _updateDiscount,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملاحظات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: _notesController,
            placeholder: 'ملاحظات إضافية (اختياري)',
            maxLines: 3,
            padding: const EdgeInsets.all(12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(cart) {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: CupertinoButton.filled(
            onPressed: _isProcessing ? null : _processSale,
            child: _isProcessing
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : const Text(
                    'إتمام البيع',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  void _updateDiscount(String value) {
    final discount = double.tryParse(value) ?? 0.0;
    ref.read(cartProvider.notifier).updateCartDiscount(discount);
  }

  Future<void> _processSale() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final cart = ref.read(cartProvider);
      final invoiceRepository = InvoiceRepository();
      final customerRepository = CustomerRepository();

      // إنشاء عميل جديد إذا تم إدخال بيانات
      int? customerId;
      if (_customerNameController.text.isNotEmpty) {
        final customer = Customer(
          name: _customerNameController.text,
          phone: _customerPhoneController.text.isNotEmpty
              ? _customerPhoneController.text
              : null,
        );
        customerId = await customerRepository.insertCustomer(customer);
      }

      // إنشاء رقم فاتورة فريد
      final invoiceNumber = await _generateInvoiceNumber();

      // إنشاء الفاتورة
      final invoice = Invoice(
        invoiceNumber: invoiceNumber,
        customerId: customerId,
        subtotal: cart.subtotal,
        discount: cart.totalDiscount,
        tax: cart.taxAmount,
        total: cart.total,
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        userId: 1, // سيتم ربطه بنظام المستخدمين في التحديث القادم
      );

      // حفظ الفاتورة مع الأصناف
      await invoiceRepository.createSaleTransaction(invoice, cart.items);

      // مسح السلة
      ref.read(cartProvider.notifier).clearCart();

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('تم البيع بنجاح'),
            content: Text('رقم الفاتورة: $invoiceNumber'),
            actions: [
              CupertinoDialogAction(
                child: const Text('طباعة'),
                onPressed: () {
                  Navigator.pop(context);
                  _showPrintOptions(invoice, cart.items);
                },
              ),
              CupertinoDialogAction(
                child: const Text('موافق'),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // العودة لشاشة نقطة البيع
                },
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('خطأ'),
            content: Text('حدث خطأ أثناء معالجة البيع: $error'),
            actions: [
              CupertinoDialogAction(
                child: const Text('موافق'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<String> _generateInvoiceNumber() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // الحصول على عدد الفواتير اليوم
    final invoiceRepository = InvoiceRepository();
    final todayCount = await invoiceRepository.getTodayInvoiceCount();

    return 'INV$dateStr${(todayCount + 1).toString().padLeft(3, '0')}';
  }

  void _showPrintOptions(Invoice invoice, List<CartItem> items) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('خيارات الطباعة'),
        message: const Text('اختر نوع الطباعة المطلوب'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('طباعة PDF'),
            onPressed: () {
              Navigator.pop(context);
              _printInvoicePDF(invoice, items);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('طباعة حرارية'),
            onPressed: () {
              Navigator.pop(context);
              _printInvoiceThermal(invoice, items);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('إلغاء'),
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context); // العودة لشاشة نقطة البيع
          },
        ),
      ),
    );
  }

  void _printInvoicePDF(Invoice invoice, List<CartItem> items) async {
    try {
      await ref
          .read(printNotifierProvider.notifier)
          .printInvoicePDF(invoice, items);

      if (mounted) {
        _showSuccessMessage('تم إرسال الفاتورة للطباعة بنجاح');
        Navigator.pop(context); // العودة لشاشة نقطة البيع
      }
    } catch (error) {
      if (mounted) {
        _showErrorMessage('خطأ في الطباعة: $error');
      }
    }
  }

  void _printInvoiceThermal(Invoice invoice, List<CartItem> items) async {
    try {
      await ref
          .read(printNotifierProvider.notifier)
          .printInvoiceThermal(invoice, items);

      if (mounted) {
        _showSuccessMessage('تم طباعة الفاتورة على الطابعة الحرارية بنجاح');
        Navigator.pop(context); // العودة لشاشة نقطة البيع
      }
    } catch (error) {
      if (mounted) {
        _showErrorMessage('خطأ في الطباعة الحرارية: $error');
      }
    }
  }

  void _showSuccessMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('تم بنجاح'),
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

  void _showErrorMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('خطأ'),
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
}
