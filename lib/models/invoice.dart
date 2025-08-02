enum PaymentMethod {
  cash('نقدي'),
  card('بطاقة'),
  installment('تقسيط');

  const PaymentMethod(this.displayName);
  final String displayName;
}

class Invoice {
  final int? id;
  final String invoiceNumber;
  final int? customerId;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final PaymentMethod paymentMethod;
  final String? notes;
  final DateTime createdAt;
  final int userId;

  Invoice({
    this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    required this.paymentMethod,
    this.notes,
    DateTime? createdAt,
    required this.userId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'payment_method': paymentMethod.name,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id']?.toInt(),
      invoiceNumber: map['invoice_number'] ?? '',
      customerId: map['customer_id']?.toInt(),
      subtotal: map['subtotal']?.toDouble() ?? 0.0,
      discount: map['discount']?.toDouble() ?? 0.0,
      tax: map['tax']?.toDouble() ?? 0.0,
      total: map['total']?.toDouble() ?? 0.0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == map['payment_method'],
        orElse: () => PaymentMethod.cash,
      ),
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      userId: map['user_id']?.toInt() ?? 0,
    );
  }

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    int? customerId,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    PaymentMethod? paymentMethod,
    String? notes,
    DateTime? createdAt,
    int? userId,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }

  @override
  String toString() {
    return 'Invoice(id: $id, invoiceNumber: $invoiceNumber, total: $total)';
  }
}

class InvoiceItem {
  final int? id;
  final int invoiceId;
  final int itemId;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  InvoiceItem({
    this.id,
    required this.invoiceId,
    required this.itemId,
    this.quantity = 1.0,
    required this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'item_id': itemId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id']?.toInt(),
      invoiceId: map['invoice_id']?.toInt() ?? 0,
      itemId: map['item_id']?.toInt() ?? 0,
      quantity: map['quantity']?.toDouble() ?? 1.0,
      unitPrice: map['unit_price']?.toDouble() ?? 0.0,
      totalPrice: map['total_price']?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'InvoiceItem(id: $id, itemId: $itemId, totalPrice: $totalPrice)';
  }
}
