import 'item.dart';

class CartItem {
  final Item item;
  final double quantity;
  final double unitPrice;
  final double discount;

  CartItem({
    required this.item,
    this.quantity = 1.0,
    required this.unitPrice,
    this.discount = 0.0,
  });

  double get totalPrice => (unitPrice * quantity) - discount;

  CartItem copyWith({
    Item? item,
    double? quantity,
    double? unitPrice,
    double? discount,
  }) {
    return CartItem(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
    );
  }

  @override
  String toString() {
    return 'CartItem(item: ${item.sku}, quantity: $quantity, unitPrice: $unitPrice, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem &&
        other.item.id == item.id &&
        other.quantity == quantity &&
        other.unitPrice == unitPrice &&
        other.discount == discount;
  }

  @override
  int get hashCode {
    return item.id.hashCode ^
        quantity.hashCode ^
        unitPrice.hashCode ^
        discount.hashCode;
  }
}

class Cart {
  final List<CartItem> items;
  final double discount;
  final double taxRate;
  final String? notes;

  Cart({
    this.items = const [],
    this.discount = 0.0,
    this.taxRate = 0.0,
    this.notes,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  
  double get totalDiscount => discount + items.fold(0.0, (sum, item) => sum + item.discount);
  
  double get taxAmount => (subtotal - totalDiscount) * taxRate;
  
  double get total => subtotal - totalDiscount + taxAmount;
  
  int get itemCount => items.length;
  
  bool get isEmpty => items.isEmpty;
  
  bool get isNotEmpty => items.isNotEmpty;

  Cart copyWith({
    List<CartItem>? items,
    double? discount,
    double? taxRate,
    String? notes,
  }) {
    return Cart(
      items: items ?? this.items,
      discount: discount ?? this.discount,
      taxRate: taxRate ?? this.taxRate,
      notes: notes ?? this.notes,
    );
  }

  Cart addItem(CartItem cartItem) {
    final existingIndex = items.indexWhere((item) => item.item.id == cartItem.item.id);
    
    if (existingIndex >= 0) {
      // إذا كان الصنف موجود، نحديث الكمية
      final updatedItems = List<CartItem>.from(items);
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + cartItem.quantity,
      );
      return copyWith(items: updatedItems);
    } else {
      // إضافة صنف جديد
      return copyWith(items: [...items, cartItem]);
    }
  }

  Cart removeItem(int itemId) {
    return copyWith(
      items: items.where((item) => item.item.id != itemId).toList(),
    );
  }

  Cart updateItemQuantity(int itemId, double quantity) {
    if (quantity <= 0) {
      return removeItem(itemId);
    }

    final updatedItems = items.map((item) {
      if (item.item.id == itemId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    return copyWith(items: updatedItems);
  }

  Cart updateItemDiscount(int itemId, double discount) {
    final updatedItems = items.map((item) {
      if (item.item.id == itemId) {
        return item.copyWith(discount: discount);
      }
      return item;
    }).toList();

    return copyWith(items: updatedItems);
  }

  Cart clear() {
    return Cart(
      discount: 0.0,
      taxRate: taxRate,
      notes: null,
    );
  }

  @override
  String toString() {
    return 'Cart(items: ${items.length}, subtotal: $subtotal, total: $total)';
  }
}
