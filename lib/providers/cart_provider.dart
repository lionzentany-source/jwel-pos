import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../models/item.dart';
import 'settings_provider.dart';
import 'item_provider.dart';
import 'rfid_provider.dart';
import 'material_provider.dart';
import '../utils/rfid_duplicate_filter.dart';

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
      final goldPrice = await settingsRepository.getGoldPrice() ?? 0.0;
      // محاولة الحصول على سعر خاص بالمادة
      double? materialPrice;
      final materialsState = _ref.read(materialNotifierProvider);
      materialsState.whenData((materials) {
        final mat = materials.firstWhere(
          (m) => m.id == item.materialId,
          orElse: () => materials.first,
        );
        if (mat.isVariable) materialPrice = mat.pricePerGram;
      });
      final unitPrice = item.calculateTotalPrice(goldPrice, materialSpecificPrice: materialPrice);

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
    // مسح قائمة البطاقات المقروءة عند حذف صنف
    final rfidService = _ref.read(rfidServiceProvider);
    rfidService.clearRecentlyReadTags();
    RfidDuplicateFilter.clear();
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
    // مسح قائمة البطاقات المقروءة عند مسح السلة
    final rfidService = _ref.read(rfidServiceProvider);
    rfidService.clearRecentlyReadTags();
    RfidDuplicateFilter.clear();
  }

  // دالة لإضافة صنف مباشرة عبر بطاقة RFID
  Future<bool> addItemByRfidTag(String rfidTag) async {
    try {
      debugPrint('🏷️ البحث عن صنف ببطاقة RFID: $rfidTag');
      final itemRepository = _ref.read(itemRepositoryProvider);
      // محاولة استعلام مباشر إذا كان متاحاً
      Item? foundItem;
      try {
        // هذه الدالة تم تعريفها مسبقاً في المستودع (حسب التعديلات السابقة)
        // نتجاهل الخطأ إذا لم تكن موجودة
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        foundItem = await itemRepository.getItemByRfidTag(rfidTag);
      } catch (_) {}
      if (foundItem == null) {
        final allItems = await itemRepository.getAllItems();
        foundItem = allItems.firstWhere(
          (item) => item.rfidTag == rfidTag,
          orElse: () => Item(
            sku: '',
            categoryId: 0,
            materialId: 0,
            weightGrams: 0,
            karat: 0,
            workmanshipFee: 0,
          ),
        );
      }

      if (foundItem.sku.isEmpty) {
        debugPrint('❌ لم يتم العثور على صنف ببطاقة RFID: $rfidTag');
        return false;
      }

      // التحقق من عدم وجوده في السلة أولاً
      if (state.items.any((cartItem) => cartItem.item.id == foundItem!.id)) {
        debugPrint('⚠️ الصنف ${foundItem.sku} موجود في السلة بالفعل');
        return false;
      }

      // التحقق من الحالة
      if (foundItem.status == ItemStatus.sold) {
        debugPrint('❌ الصنف ${foundItem.sku} مباع بالفعل');
        return false;
      }

      if (foundItem.status != ItemStatus.inStock &&
          foundItem.status != ItemStatus.needsRfid) {
        debugPrint('❌ الصنف ${foundItem.sku} غير متاح للبيع');
        return false;
      }

      // إضافة الصنف
      final settingsRepository = _ref.read(settingsRepositoryProvider);
      final goldPrice = await settingsRepository.getGoldPrice() ?? 0.0;
      double? materialPrice;
      final materialsState = _ref.read(materialNotifierProvider);
      materialsState.whenData((materials) {
        final mat = materials.firstWhere(
          (m) => m.id == foundItem!.materialId,
          orElse: () => materials.first,
        );
        if (mat.isVariable) materialPrice = mat.pricePerGram;
      });
      final unitPrice = foundItem.calculateTotalPrice(goldPrice, materialSpecificPrice: materialPrice);
      _addItem(foundItem, unitPrice);

      debugPrint(
        '✅ تم إضافة الصنف: ${foundItem.sku} - السعر: ${unitPrice.toStringAsFixed(2)}',
      );
      return true;
    } catch (error) {
      debugPrint('❌ خطأ في إضافة الصنف: $error');
      return false;
    }
  }

  // دالة لإضافة صنف عبر البحث (للبحث اليدوي)
  Future<bool> addItemBySearch(String searchQuery) async {
    try {
      debugPrint('🔍 البحث عن صنف: $searchQuery');
      final itemRepository = _ref.read(itemRepositoryProvider);
      final allItems = await itemRepository.getAllItems();

      // نفس منطق البحث في المخزون
      final query = searchQuery.toLowerCase();
      final foundItems = allItems.where((item) {
        // إخفاء الأصناف المباعة
        if (item.status == ItemStatus.sold) return false;

        // البحث في SKU أو RFID tag
        final searchMatches =
            item.sku.toLowerCase().contains(query) ||
            item.rfidTag?.toLowerCase().contains(query) == true;
        return searchMatches;
      }).toList();

      if (foundItems.isEmpty) {
        debugPrint('❌ لم يتم العثور على أصناف بالبحث: $searchQuery');
        return false;
      }

      debugPrint('✅ تم العثور على ${foundItems.length} صنف');

      int addedCount = 0;
      final settingsRepository = _ref.read(settingsRepositoryProvider);
      final goldPrice = await settingsRepository.getGoldPrice() ?? 0.0;

      // إضافة جميع النتائج دون تكرار
      for (final item in foundItems) {
        // التحقق من الحالة
        if (item.status != ItemStatus.inStock &&
            item.status != ItemStatus.needsRfid) {
          debugPrint('⚠️ تخطي الصنف ${item.sku} - غير متاح للبيع');
          continue;
        }

        // التحقق من عدم وجوده في السلة
        if (state.items.any((cartItem) => cartItem.item.id == item.id)) {
          debugPrint('⚠️ تخطي الصنف ${item.sku} - موجود في السلة');
          continue;
        }

        // إضافة الصنف
        double? materialPrice;
        final materialsState = _ref.read(materialNotifierProvider);
        materialsState.whenData((materials) {
          final mat = materials.firstWhere(
            (m) => m.id == item.materialId,
            orElse: () => materials.first,
          );
          if (mat.isVariable) materialPrice = mat.pricePerGram;
        });
        final unitPrice = item.calculateTotalPrice(goldPrice, materialSpecificPrice: materialPrice);
        _addItem(item, unitPrice);
        addedCount++;
        debugPrint(
          '🛒 تم إضافة الصنف: ${item.sku} - السعر: ${unitPrice.toStringAsFixed(2)}',
        );
      }

      debugPrint('✅ تم إضافة $addedCount صنف للسلة');
      return addedCount > 0;
    } catch (error) {
      debugPrint('❌ خطأ في إضافة الصنف: $error');
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
