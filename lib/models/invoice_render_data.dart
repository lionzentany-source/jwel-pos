import 'cart_item.dart';
import 'invoice.dart';

/// نموذج موحد لتجميع بيانات الفاتورة للطباعة بأي نمط (PDF / HTML / حراري)
class InvoiceRenderData {
  final String storeName;
  final String? storeAddress;
  final String? storePhone;
  final bool showLogo;
  final String invoiceNumber;
  final DateTime date;
  final String paymentMethod;
  final String? customerName;
  final List<CartItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? notes;
  final String? cashierName;
  final String? footerText;

  const InvoiceRenderData({
    required this.storeName,
    this.storeAddress,
    this.storePhone,
    this.showLogo = true,
    required this.invoiceNumber,
    required this.date,
    required this.paymentMethod,
    this.customerName,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    this.notes,
    this.cashierName,
    this.footerText,
  });

  factory InvoiceRenderData.fromModels({
    required Invoice invoice,
    required List<CartItem> items,
    required String storeName,
    String? storeAddress,
    String? storePhone,
    String? customerName,
    String? cashierName,
    bool showLogo = true,
    String? footerText,
  }) {
    return InvoiceRenderData(
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      showLogo: showLogo,
      invoiceNumber: invoice.invoiceNumber,
      date: invoice.createdAt,
      paymentMethod: invoice.paymentMethod.displayName,
      customerName: customerName,
      items: items,
      subtotal: invoice.subtotal,
      discount: invoice.discount,
      tax: invoice.tax,
      total: invoice.total,
      notes: invoice.notes,
      cashierName: cashierName,
      footerText: footerText,
    );
  }
}
