import 'package:flutter_test/flutter_test.dart';
import 'package:jwe_pos/models/item.dart';
import 'package:jwe_pos/models/category.dart';

import 'package:jwe_pos/models/cart_item.dart';

void main() {
  group('Item Model Tests', () {
    test('should calculate total price correctly', () {
      final item = Item(
        sku: 'TEST001',
        categoryId: 1,
        materialId: 1,
        weightGrams: 10.0,
        karat: 18,
        workmanshipFee: 50.0,
        stonePrice: 25.0,
      );

      final goldPricePerGram = 200.0;
      final expectedTotal = (10.0 * 200.0) + 50.0 + 25.0; // 2075.0

      expect(item.calculateTotalPrice(goldPricePerGram), equals(expectedTotal));
    });

    test('should create item from map correctly', () {
      final map = {
        'id': 1,
        'sku': 'TEST001',
        'category_id': 1,
        'material_id': 1,
        'weight_grams': 10.0,
        'karat': 18,
        'workmanship_fee': 50.0,
        'stone_price': 25.0,
        'status': 'inStock',
        'created_at': DateTime.now().toIso8601String(),
      };

      final item = Item.fromMap(map);

      expect(item.sku, equals('TEST001'));
      expect(item.weightGrams, equals(10.0));
      expect(item.karat, equals(18));
      expect(item.status, equals(ItemStatus.inStock));
    });
  });

  group('Category Model Tests', () {
    test('should create category correctly', () {
      final category = Category(nameAr: 'خواتم', iconName: 'ring');

      expect(category.nameAr, equals('خواتم'));
      expect(category.iconName, equals('ring'));
    });

    test('should convert to map correctly', () {
      final category = Category(id: 1, nameAr: 'خواتم', iconName: 'ring');

      final map = category.toMap();

      expect(map['id'], equals(1));
      expect(map['name_ar'], equals('خواتم'));
      expect(map['icon_name'], equals('ring'));
    });
  });

  group('Cart Tests', () {
    test('should add items to cart correctly', () {
      final item = Item(
        id: 1,
        sku: 'TEST001',
        categoryId: 1,
        materialId: 1,
        weightGrams: 10.0,
        karat: 18,
        workmanshipFee: 50.0,
      );

      final cartItem = CartItem(item: item, quantity: 2.0, unitPrice: 100.0);

      final cart = Cart().addItem(cartItem);

      expect(cart.itemCount, equals(1));
      expect(cart.items.first.quantity, equals(2.0));
      expect(cart.subtotal, equals(200.0));
    });

    test('should calculate cart total correctly', () {
      final item1 = Item(
        id: 1,
        sku: 'TEST001',
        categoryId: 1,
        materialId: 1,
        weightGrams: 10.0,
        karat: 18,
        workmanshipFee: 50.0,
      );

      final item2 = Item(
        id: 2,
        sku: 'TEST002',
        categoryId: 1,
        materialId: 1,
        weightGrams: 5.0,
        karat: 21,
        workmanshipFee: 30.0,
      );

      final cartItem1 = CartItem(item: item1, quantity: 1.0, unitPrice: 100.0);
      final cartItem2 = CartItem(item: item2, quantity: 2.0, unitPrice: 80.0);

      final cart = Cart()
          .addItem(cartItem1)
          .addItem(cartItem2)
          .copyWith(discount: 20.0, taxRate: 0.1);

      expect(cart.subtotal, equals(260.0)); // 100 + (80 * 2)
      expect(cart.totalDiscount, equals(20.0));
      expect(cart.taxAmount, equals(24.0)); // (260 - 20) * 0.1
      expect(cart.total, equals(264.0)); // 260 - 20 + 24
    });

    test('should remove items from cart correctly', () {
      final item = Item(
        id: 1,
        sku: 'TEST001',
        categoryId: 1,
        materialId: 1,
        weightGrams: 10.0,
        karat: 18,
        workmanshipFee: 50.0,
      );

      final cartItem = CartItem(item: item, quantity: 1.0, unitPrice: 100.0);
      final cart = Cart().addItem(cartItem).removeItem(1);

      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, equals(0));
    });
  });
}
