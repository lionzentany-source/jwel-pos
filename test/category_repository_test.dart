import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwe_pos/repositories/category_repository.dart';
import 'package:jwe_pos/models/category.dart';
import 'package:jwe_pos/services/database_service.dart';

// Manual Mock classes
class MockDatabase extends Mock implements Database {}

class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  group('CategoryRepository', () {
    late CategoryRepository categoryRepository;
    late MockDatabase mockDatabase;
    late MockDatabaseService mockDatabaseService;

    setUp(() {
      mockDatabase = MockDatabase();
      mockDatabaseService = MockDatabaseService();

      // Setup the database service to return our mock database
      when(mockDatabaseService.database).thenAnswer((_) async => mockDatabase);

      categoryRepository = CategoryRepository(
        databaseService: mockDatabaseService,
      );
    });

    test('getAllCategories returns a list of categories', () async {
      // Arrange
      final mockResult = [
        {'id': 1, 'name_ar': 'ذهب', 'icon_name': 'gold'},
        {'id': 2, 'name_ar': 'فضة', 'icon_name': 'silver'},
      ];

      when(
        mockDatabase.query('categories', orderBy: 'name_ar ASC'),
      ).thenAnswer((_) async => mockResult);

      // Act
      final categories = await categoryRepository.getAllCategories();

      // Assert
      expect(categories.length, 2);
      expect(categories[0].nameAr, 'ذهب');
      expect(categories[1].nameAr, 'فضة');
      verify(
        mockDatabase.query('categories', orderBy: 'name_ar ASC'),
      ).called(1);
    });

    test('getCategoryById returns a category if found', () async {
      // Arrange
      final mockResult = [
        {'id': 1, 'name_ar': 'ذهب', 'icon_name': 'gold'},
      ];

      when(
        mockDatabase.query(
          'categories',
          where: 'id = ?',
          whereArgs: [1],
          limit: 1,
        ),
      ).thenAnswer((_) async => mockResult);

      // Act
      final category = await categoryRepository.getCategoryById(1);

      // Assert
      expect(category, isNotNull);
      expect(category?.id, 1);
      expect(category?.nameAr, 'ذهب');
      verify(
        mockDatabase.query(
          'categories',
          where: 'id = ?',
          whereArgs: [1],
          limit: 1,
        ),
      ).called(1);
    });

    test('getCategoryById returns null if not found', () async {
      // Arrange
      when(
        mockDatabase.query(
          'categories',
          where: 'id = ?',
          whereArgs: [99],
          limit: 1,
        ),
      ).thenAnswer((_) async => []);

      // Act
      final category = await categoryRepository.getCategoryById(99);

      // Assert
      expect(category, isNull);
    });

    test('insertCategory inserts a category and returns its id', () async {
      // Arrange
      final category = Category(nameAr: 'بلاتين', iconName: 'platinum');
      when(
        mockDatabase.insert('categories', category.toMap()),
      ).thenAnswer((_) async => 1);

      // Act
      final id = await categoryRepository.insertCategory(category);

      // Assert
      expect(id, 1);
      verify(mockDatabase.insert('categories', category.toMap())).called(1);
    });

    test(
      'updateCategory updates a category and returns number of rows affected',
      () async {
        // Arrange
        final category = Category(
          id: 1,
          nameAr: 'ذهب محدث',
          iconName: 'updated_gold',
        );
        when(
          mockDatabase.update(
            'categories',
            category.toMap(),
            where: 'id = ?',
            whereArgs: [1],
          ),
        ).thenAnswer((_) async => 1);

        // Act
        final rowsAffected = await categoryRepository.updateCategory(category);

        // Assert
        expect(rowsAffected, 1);
        verify(
          mockDatabase.update(
            'categories',
            category.toMap(),
            where: 'id = ?',
            whereArgs: [1],
          ),
        ).called(1);
      },
    );

    test(
      'deleteCategory deletes a category and returns number of rows affected',
      () async {
        // Arrange - No items associated
        when(
          mockDatabase.rawQuery(
            'SELECT COUNT(*) as count FROM items WHERE category_id = ?',
            [1],
          ),
        ).thenAnswer(
          (_) async => [
            {'count': 0},
          ],
        );

        when(
          mockDatabase.delete('categories', where: 'id = ?', whereArgs: [1]),
        ).thenAnswer((_) async => 1);

        // Act
        final rowsAffected = await categoryRepository.deleteCategory(1);

        // Assert
        expect(rowsAffected, 1);
        verify(
          mockDatabase.rawQuery(
            'SELECT COUNT(*) as count FROM items WHERE category_id = ?',
            [1],
          ),
        ).called(1);
        verify(
          mockDatabase.delete('categories', where: 'id = ?', whereArgs: [1]),
        ).called(1);
      },
    );

    test(
      'deleteCategory throws exception if category has associated items',
      () async {
        // Arrange - Has associated items
        when(
          mockDatabase.rawQuery(
            'SELECT COUNT(*) as count FROM items WHERE category_id = ?',
            [1],
          ),
        ).thenAnswer(
          (_) async => [
            {'count': 5},
          ],
        );

        // Act & Assert
        expect(
          () => categoryRepository.deleteCategory(1),
          throwsA(isA<Exception>()),
        );

        verify(
          mockDatabase.rawQuery(
            'SELECT COUNT(*) as count FROM items WHERE category_id = ?',
            [1],
          ),
        ).called(1);

        // Verify delete was never called
        verifyNever(mockDatabase.delete(any, where: any, whereArgs: any));
      },
    );

    test('categoryExists returns true when category exists', () async {
      // Arrange
      when(
        mockDatabase.query(
          'categories',
          where: 'name_ar = ?',
          whereArgs: ['ذهب'],
          limit: 1,
        ),
      ).thenAnswer(
        (_) async => [
          {'id': 1, 'name_ar': 'ذهب', 'icon_name': 'gold'},
        ],
      );

      // Act
      final exists = await categoryRepository.categoryExists('ذهب');

      // Assert
      expect(exists, true);
    });

    test('categoryExists returns false when category does not exist', () async {
      // Arrange
      when(
        mockDatabase.query(
          'categories',
          where: 'name_ar = ?',
          whereArgs: ['غير موجود'],
          limit: 1,
        ),
      ).thenAnswer((_) async => []);

      // Act
      final exists = await categoryRepository.categoryExists('غير موجود');

      // Assert
      expect(exists, false);
    });
  });
}
