import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwe_pos/repositories/material_repository.dart';
import 'package:jwe_pos/models/material.dart';
import 'package:jwe_pos/services/database_service.dart';

// Mock classes
class MockDatabase extends Mock implements Database {}

class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  group('MaterialRepository', () {
    late MaterialRepository materialRepository;
    late MockDatabase mockDatabase;
    late MockDatabaseService mockDatabaseService;

    setUp(() {
      DatabaseService.resetForTesting();
      mockDatabase = MockDatabase();
      mockDatabaseService = MockDatabaseService();
      when(mockDatabaseService.database).thenAnswer((_) async => mockDatabase);
      DatabaseService.testInstance = mockDatabaseService;
      materialRepository = MaterialRepository(
        databaseService: mockDatabaseService,
      );
    });

    tearDown(() {
      DatabaseService.resetForTesting();
    });

    void mockQueryResult(List<Map<String, dynamic>> result) {
      when(
        mockDatabase.query(
          'materials',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
          limit: anyNamed('limit'),
          orderBy: anyNamed('orderBy'),
        ),
      ).thenAnswer((_) async => result);
    }

    void mockRawQueryResult(List<Map<String, dynamic>> result) {
      when(
        mockDatabase.rawQuery(
          'SELECT COUNT(*) as count FROM items WHERE material_id = ?',
          [any],
        ),
      ).thenAnswer((_) async => result);
    }

    test('getAllMaterials returns a list of materials', () async {
      mockQueryResult([
        {'id': 1, 'name_ar': 'ذهب عيار 21'},
        {'id': 2, 'name_ar': 'فضة عيار 925'},
      ]);

      final materials = await materialRepository.getAllMaterials();
      expect(materials.length, 2);
      expect(materials[0].nameAr, 'ذهب عيار 21');
      expect(materials[1].nameAr, 'فضة عيار 925');
    });

    test('getMaterialById returns a material if found', () async {
      mockQueryResult([
        {'id': 1, 'name_ar': 'ذهب عيار 21'},
      ]);

      final material = await materialRepository.getMaterialById(1);
      expect(material, isNotNull);
      expect(material?.id, 1);
      expect(material?.nameAr, 'ذهب عيار 21');
    });

    test('getMaterialById returns null if not found', () async {
      mockQueryResult([]);

      final material = await materialRepository.getMaterialById(99);
      expect(material, isNull);
    });

    test('insertMaterial inserts a material and returns its id', () async {
      when(
        mockDatabase.insert('materials', any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);

      final material = Material(nameAr: 'بلاتين');
      final id = await materialRepository.insertMaterial(material);
      expect(id, 1);
      verify(
        mockDatabase.insert('materials', any as Map<String, Object?>),
      ).called(1);
    });

    test(
      'updateMaterial updates a material and returns number of rows affected',
      () async {
        when(
          mockDatabase.update(
            'materials',
            any as Map<String, Object?>,
            where: anyNamed('where'),
            whereArgs: anyNamed('whereArgs'),
          ),
        ).thenAnswer((_) async => 1);

        final material = Material(id: 1, nameAr: 'ذهب محدث');
        final rowsAffected = await materialRepository.updateMaterial(material);
        expect(rowsAffected, 1);
        verify(
          mockDatabase.update(
            'materials',
            any as Map<String, Object?>,
            where: 'id = ?',
            whereArgs: [1],
          ),
        ).called(1);
      },
    );

    test(
      'deleteMaterial deletes a material and returns number of rows affected',
      () async {
        mockRawQueryResult([
          {'count': 0},
        ]); // No items associated
        when(
          mockDatabase.delete(
            'materials',
            where: anyNamed('where'),
            whereArgs: anyNamed('whereArgs'),
          ),
        ).thenAnswer((_) async => 1);

        final rowsAffected = await materialRepository.deleteMaterial(1);
        expect(rowsAffected, 1);
        verify(
          mockDatabase.delete('materials', where: 'id = ?', whereArgs: [1]),
        ).called(1);
      },
    );

    test(
      'deleteMaterial throws exception if material has associated items',
      () async {
        mockRawQueryResult([
          {'count': 5},
        ]); // Has associated items

        expect(() => materialRepository.deleteMaterial(1), throwsException);
      },
    );
  });
}
