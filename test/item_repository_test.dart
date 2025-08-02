import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwe_pos/repositories/item_repository.dart';
import 'package:jwe_pos/models/item.dart';
import 'package:jwe_pos/services/database_service.dart';

// Mock classes
class MockDatabase extends Mock implements Database {}

class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  group('ItemRepository', () {
    late ItemRepository itemRepository;
    late MockDatabase mockDatabase;
    late MockDatabaseService mockDatabaseService;

    setUp(() {
      DatabaseService.resetForTesting();
      mockDatabase = MockDatabase();
      mockDatabaseService = MockDatabaseService();
      when(mockDatabaseService.database).thenAnswer((_) async => mockDatabase);
      DatabaseService.testInstance = mockDatabaseService;
      itemRepository = ItemRepository(databaseService: mockDatabaseService);
    });

    tearDown(() {
      DatabaseService.resetForTesting();
    });

    void mockQueryResult(List<Map<String, dynamic>> result) {
      when(
        mockDatabase.query(
          'items',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          limit: anyNamed('limit'),
          orderBy: anyNamed('orderBy'),
        ),
      ).thenAnswer((_) async => result);
    }

    void mockRawQueryResult(List<Map<String, dynamic>> result) {
      when(
        mockDatabase.rawQuery(any as String, any as List<Object?>),
      ).thenAnswer((_) async => result);
    }

    test('getAllItems returns a list of items', () async {
      mockQueryResult([
        {
          'id': 1,
          'sku': 'ITEM001',
          'category_id': 1,
          'material_id': 1,
          'weight_grams': 5.5,
          'karat': 21,
          'workmanship_fee': 100.0,
          'stone_price': 50.0,
          'status': 'inStock',
          'rfid_tag': null,
          'image_path': null,
          'created_at': '2023-01-01T00:00:00.000Z',
        },
      ]);

      final items = await itemRepository.getAllItems();
      expect(items.length, 1);
      expect(items[0].sku, 'ITEM001');
    });

    test('getItemById returns an item if found', () async {
      mockQueryResult([
        {
          'id': 1,
          'sku': 'ITEM001',
          'category_id': 1,
          'material_id': 1,
          'weight_grams': 5.5,
          'karat': 21,
          'workmanship_fee': 100.0,
          'stone_price': 50.0,
          'status': 'inStock',
          'rfid_tag': null,
          'image_path': null,
          'created_at': '2023-01-01T00:00:00.000Z',
        },
      ]);

      final item = await itemRepository.getItemById(1);
      expect(item, isNotNull);
      expect(item?.id, 1);
      expect(item?.sku, 'ITEM001');
    });

    test('getItemById returns null if not found', () async {
      mockQueryResult([]);

      final item = await itemRepository.getItemById(99);
      expect(item, isNull);
    });

    test('insertItem inserts an item and returns its id', () async {
      when(
        mockDatabase.insert('items', any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);

      final item = Item(
        sku: 'ITEM002',
        categoryId: 2,
        materialId: 2,
        weightGrams: 3.0,
        karat: 18,
        workmanshipFee: 80.0,
        stonePrice: 20.0,
        status: ItemStatus.inStock,
      );
      final id = await itemRepository.insertItem(item);
      expect(id, 1);
      verify(
        mockDatabase.insert('items', any as Map<String, Object?>),
      ).called(1);
    });

    test(
      'updateItem updates an item and returns number of rows affected',
      () async {
        when(
          mockDatabase.update(
            'items',
            any as Map<String, Object?>,
            where: anyNamed('where'),
            whereArgs: anyNamed('whereArgs'),
          ),
        ).thenAnswer((_) async => 1);

        final item = Item(
          id: 1,
          sku: 'ITEM001',
          categoryId: 1,
          materialId: 1,
          weightGrams: 6.0,
          karat: 21,
          workmanshipFee: 120.0,
          stonePrice: 60.0,
          status: ItemStatus.inStock,
        );
        final rowsAffected = await itemRepository.updateItem(item);
        expect(rowsAffected, 1);
        verify(
          mockDatabase.update(
            'items',
            any as Map<String, Object?>,
            where: 'id = ?',
            whereArgs: [1],
          ),
        ).called(1);
      },
    );

    test(
      'deleteItem deletes an item and returns number of rows affected',
      () async {
        mockRawQueryResult([
          {'count': 0},
        ]); // No invoices associated
        when(
          mockDatabase.delete(
            'items',
            where: anyNamed('where'),
            whereArgs: anyNamed('whereArgs'),
          ),
        ).thenAnswer((_) async => 1);

        final rowsAffected = await itemRepository.deleteItem(1);
        expect(rowsAffected, 1);
        verify(
          mockDatabase.delete('items', where: 'id = ?', whereArgs: [1]),
        ).called(1);
      },
    );

    test(
      'deleteItem throws exception if item has associated invoices',
      () async {
        mockRawQueryResult([
          {'count': 2},
        ]); // Has associated invoices

        expect(() => itemRepository.deleteItem(1), throwsException);
      },
    );

    test('generateNextSku generates a unique SKU', () async {
      mockRawQueryResult([
        {'max_sku': 'ITEM005'},
      ]);

      final nextSku = await itemRepository.generateNextSku();
      expect(nextSku, 'ITEM006');
    });

    test('linkRfidTag links RFID tag to item', () async {
      mockRawQueryResult([
        {'count': 0},
      ]); // RFID tag not in use
      when(
        mockDatabase.update(
          'items',
          any as Map<String, Object?>,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ),
      ).thenAnswer((_) async => 1);

      final success = await itemRepository.linkRfidTag(1, 'RFID123');
      expect(success, isTrue);
      verify(
        mockDatabase.update(
          'items',
          any as Map<String, Object?>,
          where: 'id = ?',
          whereArgs: [1],
        ),
      ).called(1);
    });

    test('linkRfidTag throws exception if RFID tag already in use', () async {
      mockRawQueryResult([
        {'count': 1},
      ]); // RFID tag already in use

      expect(() => itemRepository.linkRfidTag(1, 'RFID123'), throwsException);
    });
  });
}
