import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../widgets/adaptive_scaffold.dart';

// ...existing code...
import '../models/invoice.dart';
import '../models/customer.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/print_provider.dart';
import '../services/printer_facade.dart';
import '../providers/invoice_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/item_provider.dart';
import '../models/item.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  // embedded: عرض كشاشة عائمة فوق POS بدون Route منفصل
  const CheckoutScreen({super.key, this.embedded = false, this.onClose});

  final bool embedded;
  final VoidCallback? onClose; // يُستدعى عند الإغلاق في وضع overlay

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
      title: 'الدفع/الخروج',
      backgroundColor: const Color(0xfff6f8fa),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xffffffff),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0x220078D4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 64),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildOrderSummary(cart, currency),
                      const SizedBox(height: 16),
                      _buildCustomerSection(),
                      const SizedBox(height: 16),
                      _buildPaymentMethodSection(),
                      const SizedBox(height: 16),
                      _buildDiscountSection(currency),
                      const SizedBox(height: 16),
                      _buildNotesSection(),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: const Color(0xfff6f8fa),
                  child: _buildActionButtons(cart),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(cart, AsyncValue<String> currency) {
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xfff6f8fa),
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
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xfff6f8fa),
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
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xfff6f8fa),
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
                            ? FontWeight.bold
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
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xfff6f8fa),
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
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xfff6f8fa),
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
          child: Button(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xfff6f8fa)),
              foregroundColor: WidgetStateProperty.all(const Color(0xFF0078D4)),
            ),
            onPressed: () {
              if (widget.embedded) {
                widget.onClose?.call();
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('إلغاء'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFF0078D4)),
              foregroundColor: WidgetStateProperty.all(const Color(0xffffffff)),
            ),
            onPressed: _isProcessing ? null : _processSale,
            child: _isProcessing
                ? const ProgressRing()
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
      final invoiceRepository = ref.read(invoiceRepositoryProvider);
      final customerRepository = ref.read(customerRepositoryProvider);

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
      // تحديث قائمة الأصناف لإزالة المباعة
      try {
        ref.invalidate(itemsProvider); // في حال وجود مزود للأصناف
        ref.invalidate(itemsByStatusProvider(ItemStatus.inStock));
        ref.invalidate(itemsByStatusProvider(ItemStatus.needsRfid));
        ref.invalidate(inventoryStatsProvider);
      } catch (_) {}

      if (!mounted) return; // حماية إضافية
      // إذا كنا في وضع overlay أغلقه أولاً لتختفي فوراً
      if (widget.embedded) {
        try {
          widget.onClose?.call();
        } catch (_) {}
      }
      // عرض حوار النجاح باستخدام rootNavigator مع نفس context الحالي (ما دمنا mounted)
      showCupertinoDialog(
        context: context,
        builder: (dCtx) => CupertinoAlertDialog(
          title: const Text('تم البيع بنجاح'),
          content: Text('رقم الفاتورة: $invoiceNumber'),
          actions: [
            CupertinoDialogAction(
              child: const Text('طباعة'),
              onPressed: () {
                Navigator.pop(dCtx);
                _showPrintOptions(invoice, cart.items);
              },
            ),
            CupertinoDialogAction(
              child: const Text('موافق'),
              onPressed: () {
                Navigator.pop(dCtx);
                if (!widget.embedded && mounted) {
                  Navigator.pop(
                    context,
                  ); // العودة لنقطة البيع فقط في وضع الشاشة الكاملة
                }
              },
            ),
          ],
        ),
      );
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
    final invoiceRepository = ref.read(invoiceRepositoryProvider);
    final todayCount = await invoiceRepository.getTodayInvoiceCount();

    return 'INV$dateStr${(todayCount + 1).toString().padLeft(3, '0')}';
  }

  void _showPrintOptions(Invoice invoice, List<CartItem> items) {
    // نافذة الطباعة أصبحت موحدة: طباعة مباشرة على الطابعة الافتراضية
    _printInvoiceSystem(invoice, items);
  }

  // طباعة مباشرة باستخدام طابعة النظام الافتراضية (PDF/Windows)
  Future<void> _printInvoiceSystem(
    Invoice invoice,
    List<CartItem> items,
  ) async {
    try {
      final facade = ref.read(printerFacadeProvider);
      await facade.printInvoice(
        invoice: invoice,
        items: items,
        mode: InvoicePrintMode.pdfSystem,
      );
      if (mounted) {
        _showSuccessMessage('تم إرسال الفاتورة للطابعة الافتراضية بنجاح');
        if (widget.embedded) {
          widget.onClose?.call();
        } else {
          Navigator.pop(context); // إغلاق شاشة الدفع بعد الطباعة
        }
      }
    } catch (error) {
      if (mounted) {
        _showErrorMessage('خطأ في الطباعة على طابعة النظام: $error');
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
            onPressed: () {
              if (widget.embedded) {
                widget.onClose?.call();
              } else {
                Navigator.pop(context);
              }
            },
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
            onPressed: () {
              if (widget.embedded) {
                widget.onClose?.call();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}