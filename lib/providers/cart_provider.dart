import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../models/item.dart';
import 'settings_provider.dart';
import 'item_provider.dart';

class CartNotifier extends StateNotifier<Cart> {
  CartNotifier(this._ref) : super(Cart()) {
    _loadTaxRate();
  }

  final Ref _ref;

  Future<void> _loadTaxRate() async {
    try {
      final settingsRepository = _ref.read(settingsRepositoryProvider);
      final taxRate = await settingsRepository.getTaxRate();
      state = state.copyWith(taxRate: taxRate);
    } catch (error) {
      // في حالة الخطأ، نستخدم معدل ضريبة افتراضي
      state = state.copyWith(taxRate: 0.0);
    }
  }

  Future<bool> addItem(Item item) async {
    if (state.items.any((cartItem) => cartItem.item.id == item.id)) {
      return false; // الصنف موجود بالفعل
    }

    try {
      // حساب السعر الحالي
      final settingsRepository = _ref.read(settingsRepositoryProvider);
      final goldPrice = await settingsRepository.getGoldPrice();
      final unitPrice = item.calculateTotalPrice(goldPrice);

      _addItem(item, unitPrice);
      return true;
    } catch (error) {
      return false;
    }
  }

  void _addItem(Item item, double unitPrice) {
    final cartItem = CartItem(item: item, quantity: 1.0, unitPrice: unitPrice);

    state = state.addItem(cartItem);
  }

  void removeItem(int itemId) {
    state = state.removeItem(itemId);
  }

  void updateQuantity(int itemId, double quantity) {
    state = state.updateItemQuantity(itemId, quantity);
  }

  void updateDiscount(int itemId, double discount) {
    state = state.updateItemDiscount(itemId, discount);
  }

  void updateCartDiscount(double discount) {
    state = state.copyWith(discount: discount);
  }

  void updateNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  void clearCart() {
    state = state.clear();
  }

  // دالة لإضافة صنف عبر RFID
  Future<bool> addItemByRfid(String rfidTag) async {
    try {
      final itemRepository = _ref.read(itemRepositoryProvider);
      final item = await itemRepository.getItemByRfidTag(rfidTag);

      if (item == null) {
        return false; // الصنف غير موجود
      }

      if (item.status != ItemStatus.inStock) {
        return false; // الصنف غير متاح للبيع
      }

      // حساب السعر الحالي
      final settingsRepository = _ref.read(settingsRepositoryProvider);
      final goldPrice = await settingsRepository.getGoldPrice();
      final unitPrice = item.calculateTotalPrice(goldPrice);

      _addItem(item, unitPrice);
      return true;
    } catch (error) {
      return false;
    }
  }

  // دالة للحصول على ملخص الفاتورة
  Map<String, dynamic> getInvoiceSummary() {
    return {
      'subtotal': state.subtotal,
      'discount': state.totalDiscount,
      'tax': state.taxAmount,
      'total': state.total,
      'itemCount': state.itemCount,
      'items': state.items
          .map(
            (cartItem) => {
              'itemId': cartItem.item.id,
              'sku': cartItem.item.sku,
              'quantity': cartItem.quantity,
              'unitPrice': cartItem.unitPrice,
              'totalPrice': cartItem.totalPrice,
            },
          )
          .toList(),
    };
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, Cart>((ref) {
  return CartNotifier(ref);
});

// مزود للحصول على عدد الأصناف في السلة
final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.itemCount;
});

// مزود للحصول على إجمالي السلة
final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.total;
});

// مزود للتحقق من وجود صنف في السلة
final isItemInCartProvider = Provider.family<bool, int>((ref, itemId) {
  final cart = ref.watch(cartProvider);
  return cart.items.any((cartItem) => cartItem.item.id == itemId);
});

// مزود للحصول على كمية صنف في السلة
final itemQuantityInCartProvider = Provider.family<double, int>((ref, itemId) {
  final cart = ref.watch(cartProvider);
  final cartItem = cart.items.firstWhere(
    (cartItem) => cartItem.item.id == itemId,
    orElse: () => CartItem(
      item: Item(
        sku: '',
        categoryId: 0,
        materialId: 0,
        weightGrams: 0,
        karat: 0,
        workmanshipFee: 0,
      ),
      unitPrice: 0,
    ),
  );
  return cartItem.item.sku.isNotEmpty ? cartItem.quantity : 0.0;
});
