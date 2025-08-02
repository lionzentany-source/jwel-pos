import 'package:flutter_test/flutter_test.dart';
import 'package:jwe_pos/models/category.dart';
import 'package:jwe_pos/models/material.dart';
import 'package:jwe_pos/models/item.dart';
import 'package:jwe_pos/models/cart_item.dart';

void main() {
  group('Business Logic Integration Tests', () {
    test('Complete jewelry item workflow should work correctly', () {
      // إنشاء فئة
      final category = Category(id: 1, nameAr: 'خواتم', iconName: 'ring');

      // إنشاء مادة
      final material = Material(id: 1, nameAr: 'ذهب');

      // إنشاء صنف
      final item = Item(
        id: 1,
        sku: 'JWE000001',
        categoryId: category.id!,
        materialId: material.id!,
        weightGrams: 10.0,
        karat: 18,
        workmanshipFee: 50.0,
        stonePrice: 25.0,
        status: ItemStatus.needsRfid,
      );

      // التحقق من حساب السعر
      const goldPrice = 200.0;
      final expectedPrice = (10.0 * 200.0) + 50.0 + 25.0; // 2075.0
      expect(item.calculateTotalPrice(goldPrice), equals(expectedPrice));

      // محاكاة ربط RFID
      final itemWithRfid = item.copyWith(
        rfidTag: 'RFID123456',
        status: ItemStatus.inStock,
      );
      expect(itemWithRfid.rfidTag, equals('RFID123456'));
      expect(itemWithRfid.status, equals(ItemStatus.inStock));
    });

    test('Cart operations should work correctly', () {
      // إنشاء أصناف للاختبار
      final item1 = Item(
        id: 1,
        sku: 'JWE000001',
        categoryId: 1,
        materialId: 1,
        weightGrams: 10.0,
        karat: 18,
        workmanshipFee: 50.0,
      );

      final item2 = Item(
        id: 2,
        sku: 'JWE000002',
        categoryId: 1,
        materialId: 1,
        weightGrams: 5.0,
        karat: 21,
        workmanshipFee: 30.0,
      );

      // إنشاء سلة فارغة
      var cart = Cart();
      expect(cart.isEmpty, isTrue);

      // إضافة أصناف للسلة
      final cartItem1 = CartItem(item: item1, quantity: 1.0, unitPrice: 2050.0);
      final cartItem2 = CartItem(item: item2, quantity: 2.0, unitPrice: 1030.0);

      cart = cart.addItem(cartItem1);
      cart = cart.addItem(cartItem2);

      expect(cart.itemCount, equals(2));
      expect(cart.subtotal, equals(4110.0)); // 2050 + (1030 * 2)

      // تطبيق خصم وضريبة
      cart = cart.copyWith(discount: 100.0, taxRate: 0.1);
      expect(cart.totalDiscount, equals(100.0));
      expect(cart.taxAmount, equals(401.0)); // (4110 - 100) * 0.1
      expect(cart.total, equals(4411.0)); // 4110 - 100 + 401

      // تحديث الكمية
      cart = cart.updateItemQuantity(2, 1.0);
      expect(cart.subtotal, equals(3080.0)); // 2050 + 1030

      // حذف صنف
      cart = cart.removeItem(1);
      expect(cart.itemCount, equals(1));
      expect(cart.items.first.item.id, equals(2));

      // مسح السلة
      cart = cart.clear();
      expect(cart.isEmpty, isTrue);
    });

    test('Data serialization should work correctly', () {
      // اختبار تحويل Category
      final category = Category(id: 1, nameAr: 'خواتم', iconName: 'ring');
      final categoryMap = category.toMap();
      final categoryFromMap = Category.fromMap(categoryMap);

      expect(categoryFromMap.id, equals(category.id));
      expect(categoryFromMap.nameAr, equals(category.nameAr));
      expect(categoryFromMap.iconName, equals(category.iconName));

      // اختبار تحويل Material
      final material = Material(id: 1, nameAr: 'ذهب');
      final materialMap = material.toMap();
      final materialFromMap = Material.fromMap(materialMap);

      expect(materialFromMap.id, equals(material.id));
      expect(materialFromMap.nameAr, equals(material.nameAr));

      // اختبار تحويل Item
      final item = Item(
        id: 1,
        sku: 'JWE000001',
        categoryId: 1,
        materialId: 1,
        weightGrams: 10.0,
        karat: 18,
        workmanshipFee: 50.0,
        stonePrice: 25.0,
        status: ItemStatus.inStock,
        rfidTag: 'RFID123',
      );

      final itemMap = item.toMap();
      final itemFromMap = Item.fromMap(itemMap);

      expect(itemFromMap.id, equals(item.id));
      expect(itemFromMap.sku, equals(item.sku));
      expect(itemFromMap.weightGrams, equals(item.weightGrams));
      expect(itemFromMap.karat, equals(item.karat));
      expect(itemFromMap.status, equals(item.status));
      expect(itemFromMap.rfidTag, equals(item.rfidTag));
    });

    test('Business rules should be enforced', () {
      // اختبار قواعد العمل للأصناف
      final item = Item(
        sku: 'JWE000001',
        categoryId: 1,
        materialId: 1,
        weightGrams: 0.0, // وزن صفر
        karat: 18,
        workmanshipFee: 50.0,
      );

      // يجب أن يكون السعر صفر إذا كان الوزن صفر
      expect(item.calculateTotalPrice(200.0), equals(50.0)); // فقط المصنعية

      // اختبار عيار غير صحيح
      final invalidKaratItem = Item(
        sku: 'JWE000002',
        categoryId: 1,
        materialId: 1,
        weightGrams: 10.0,
        karat: 0, // عيار غير صحيح
        workmanshipFee: 50.0,
      );

      // يجب أن يحسب السعر حتى مع عيار صفر
      expect(invalidKaratItem.calculateTotalPrice(200.0), equals(2050.0));
    });
  });
}
