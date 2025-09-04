import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../repositories/item_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/material_repository.dart';

class SampleDataService {
  final ItemRepository _itemRepository;
  final CategoryRepository _categoryRepository;
  final MaterialRepository _materialRepository;

  SampleDataService({
    ItemRepository? itemRepository,
    CategoryRepository? categoryRepository,
    MaterialRepository? materialRepository,
  }) : _itemRepository = itemRepository ?? ItemRepository(),
       _categoryRepository = categoryRepository ?? CategoryRepository(),
       _materialRepository = materialRepository ?? MaterialRepository();

  Future<void> addSampleItems() async {
    await _addSampleItemsInternal();
  }

  Future<void> resetAndAddSampleItems() async {
    // حذف جميع الأصناف الموجودة
    final existingItems = await _itemRepository.getAllItems();
    for (final item in existingItems) {
      if (item.id != null) {
        await _itemRepository.deleteItem(item.id!);
      }
    }
    debugPrint('Deleted ${existingItems.length} existing items');

    await _addSampleItemsInternal();
  }

  Future<String> generateNextSku() async {
    final maps = await _itemRepository.query(orderBy: 'id DESC', limit: 1);
    if (maps.isEmpty) {
      return 'ITEM001';
    }

    final allItems = await _itemRepository.query();
    int maxNumber = 0;

    for (final map in allItems) {
      final sku = map['sku'] as String;
      if (sku.startsWith('ITEM')) {
        final numberPart = sku.substring(4);
        final number = int.tryParse(numberPart);
        if (number != null && number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    final nextNumber = maxNumber + 1;
    return 'ITEM${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<void> _addSampleItemsInternal() async {
    debugPrint('Adding sample items...');

    // التحقق من وجود أصناف تجريبية مسبقاً
    final existingItems = await _itemRepository.getAllItems();
    if (existingItems.isNotEmpty) {
      debugPrint('Sample items already exist, skipping...');
      return;
    }

    // جلب الفئات والمواد
    final categories = await _categoryRepository.getAllCategories();
    final materials = await _materialRepository.getAllMaterials();

    if (categories.isEmpty || materials.isEmpty) {
      return; // لا يمكن إضافة أصناف بدون فئات ومواد
    }

    final goldMaterial = materials.firstWhere(
      (m) => m.nameAr == 'ذهب',
      orElse: () => materials.first,
    );
    final silverMaterial = materials.firstWhere(
      (m) => m.nameAr == 'فضة',
      orElse: () => materials.first,
    );

    final ringCategory = categories.firstWhere(
      (c) => c.nameAr == 'خواتم',
      orElse: () => categories.first,
    );
    final braceletCategory = categories.firstWhere(
      (c) => c.nameAr == 'أساور',
      orElse: () => categories.first,
    );
    final necklaceCategory = categories.firstWhere(
      (c) => c.nameAr == 'قلائد',
      orElse: () => categories.first,
    );

    debugPrint(
      'Using categories: ${categories.map((c) => c.nameAr).join(', ')}',
    );
    debugPrint('Using materials: ${materials.map((m) => m.nameAr).join(', ')}');

    // توليد رقم SKU جديد
    final nextSku = await generateNextSku();
    final baseNumber = int.parse(nextSku.substring(4));

    // إضافة أصناف تجريبية مع بطاقات RFID
    final sampleItems = [
      Item(
        sku: 'ITEM${(baseNumber).toString().padLeft(3, '0')}',
        categoryId: ringCategory.id!,
        materialId: goldMaterial.id!,
        weightGrams: 5.2,
        karat: 18,
        workmanshipFee: 50.0,
        stonePrice: 25.0,
        rfidTag: '280689400004031001',
        status: ItemStatus.inStock,
        location: ItemLocation.showroom,
      ),
      Item(
        sku: 'ITEM${(baseNumber + 1).toString().padLeft(3, '0')}',
        categoryId: ringCategory.id!,
        materialId: goldMaterial.id!,
        weightGrams: 3.8,
        karat: 21,
        workmanshipFee: 40.0,
        rfidTag: '280689400004031002',
        status: ItemStatus.inStock,
        location: ItemLocation.warehouse,
      ),
      Item(
        sku: 'ITEM${(baseNumber + 2).toString().padLeft(3, '0')}',
        categoryId: braceletCategory.id!,
        materialId: goldMaterial.id!,
        weightGrams: 12.5,
        karat: 18,
        workmanshipFee: 80.0,
        stonePrice: 15.0,
        rfidTag: '280689400004031003',
        status: ItemStatus.inStock,
        location: ItemLocation.showroom,
      ),
      Item(
        sku: 'ITEM${(baseNumber + 3).toString().padLeft(3, '0')}',
        categoryId: necklaceCategory.id!,
        materialId: goldMaterial.id!,
        weightGrams: 8.7,
        karat: 21,
        workmanshipFee: 120.0,
        status: ItemStatus.needsRfid,
        location: ItemLocation.warehouse,
      ),
      Item(
        sku: 'ITEM${(baseNumber + 4).toString().padLeft(3, '0')}',
        categoryId: ringCategory.id!,
        materialId: silverMaterial.id!,
        weightGrams: 4.2,
        karat: 925,
        workmanshipFee: 20.0,
        stonePrice: 10.0,
        rfidTag: '280689400004031005',
        status: ItemStatus.inStock,
        location: ItemLocation.showroom,
      ),
    ];

    // إدراج الأصناف
    for (final item in sampleItems) {
      final id = await _itemRepository.insertItem(item);
      debugPrint('Added item ${item.sku} with ID: $id');
    }

    debugPrint('Sample items added successfully');

    // التحقق من الإدراج
    final newItems = await _itemRepository.getAllItems();
    debugPrint('Total items after adding samples: ${newItems.length}');
  }
}
