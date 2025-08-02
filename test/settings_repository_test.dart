import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwe_pos/repositories/settings_repository.dart';
import 'package:jwe_pos/models/settings.dart';
import 'package:jwe_pos/services/database_service.dart';

// Mock classes
class MockDatabase extends Mock implements Database {}

class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  group('SettingsRepository', () {
    late SettingsRepository settingsRepository;
    late MockDatabase mockDatabase;
    late MockDatabaseService mockDatabaseService;

    setUp(() {
      DatabaseService.resetForTesting();
      mockDatabase = MockDatabase();
      mockDatabaseService = MockDatabaseService();
      when(
        mockDatabaseService.database,
      ).thenAnswer((_) async => Future.value(mockDatabase as Database));
      DatabaseService.testInstance = mockDatabaseService;
      settingsRepository = SettingsRepository(
        databaseService: mockDatabaseService,
      );
    });

    tearDown(() {
      DatabaseService.resetForTesting();
    });

    void mockQueryResult(List<Map<String, dynamic>> result) {
      when(
        mockDatabase.query(
          any as String,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs') as List<Object?>?,
          limit: anyNamed('limit'),
          orderBy: anyNamed('orderBy') as String?,
        ),
      ).thenAnswer((_) async => result);
    }

    test('getSetting returns value if found', () async {
      mockQueryResult([
        {
          'key': 'test_key',
          'value': 'test_value',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);

      final value = await settingsRepository.getSetting('test_key');
      expect(value, 'test_value');
    });

    test('getSetting returns null if not found', () async {
      mockQueryResult([]);

      final value = await settingsRepository.getSetting('non_existent_key');
      expect(value, isNull);
    });

    test('getDoubleValue returns correct double value', () async {
      mockQueryResult([
        {
          'key': 'double_key',
          'value': '123.45',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);

      final value = await settingsRepository.getDoubleValue('double_key');
      expect(value, 123.45);
    });

    test(
      'getDoubleValue returns default value if not found or invalid',
      () async {
        mockQueryResult([]);
        final value1 = await settingsRepository.getDoubleValue(
          'non_existent',
          defaultValue: 99.9,
        );
        expect(value1, 99.9);

        mockQueryResult([
          {
            'key': 'invalid_double',
            'value': 'abc',
            'updated_at': DateTime.now().toIso8601String(),
          },
        ]);
        final value2 = await settingsRepository.getDoubleValue(
          'invalid_double',
          defaultValue: 1.0,
        );
        expect(value2, 1.0);
      },
    );

    test('getIntValue returns correct int value', () async {
      mockQueryResult([
        {
          'key': 'int_key',
          'value': '123',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);

      final value = await settingsRepository.getIntValue('int_key');
      expect(value, 123);
    });

    test('getIntValue returns default value if not found or invalid', () async {
      mockQueryResult([]);
      final value1 = await settingsRepository.getIntValue(
        'non_existent',
        defaultValue: 99,
      );
      expect(value1, 99);

      mockQueryResult([
        {
          'key': 'invalid_int',
          'value': 'xyz',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);
      final value2 = await settingsRepository.getIntValue(
        'invalid_int',
        defaultValue: 1,
      );
      expect(value2, 1);
    });

    test('getBoolValue returns correct bool value', () async {
      mockQueryResult([
        {
          'key': 'bool_true',
          'value': 'true',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);
      final value1 = await settingsRepository.getBoolValue('bool_true');
      expect(value1, isTrue);

      mockQueryResult([
        {
          'key': 'bool_false',
          'value': 'false',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);
      final value2 = await settingsRepository.getBoolValue('bool_false');
      expect(value2, isFalse);
    });

    test('getBoolValue returns default value if not found', () async {
      mockQueryResult([]);
      final value = await settingsRepository.getBoolValue(
        'non_existent',
        defaultValue: true,
      );
      expect(value, isTrue);
    });

    test('setSetting inserts new setting if not exists', () async {
      mockQueryResult([]); // Simulate setting not existing
      when(
        mockDatabase.insert(any as String, any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);

      await settingsRepository.setSetting('new_key', 'new_value');
      verify(
        mockDatabase.insert(
          SettingsRepository.tableName,
          any as Map<String, Object?>,
        ),
      ).called(1);
      verifyNever(
        mockDatabase.update(
          any as String,
          any as Map<String, Object?>,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs') as List<Object?>?,
        ),
      );
    });

    test('setSetting updates existing setting if exists', () async {
      mockQueryResult([
        {
          'key': 'existing_key',
          'value': 'old_value',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]); // Simulate setting existing
      when(
        mockDatabase.update(
          any as String,
          any as Map<String, Object?>,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs') as List<Object?>?,
        ),
      ).thenAnswer((_) async => 1);

      await settingsRepository.setSetting('existing_key', 'updated_value');
      verify(
        mockDatabase.update(
          SettingsRepository.tableName,
          any as Map<String, Object?>,
          where: 'key = ?',
          whereArgs: ['existing_key'],
        ),
      ).called(1);
      verifyNever(
        mockDatabase.insert(any as String, any as Map<String, Object?>),
      );
    });

    test('setDoubleValue calls setSetting with double as string', () async {
      mockQueryResult([]);
      when(
        mockDatabase.insert(any as String, any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);
      await settingsRepository.setDoubleValue('double_setting', 123.45);
      verify(
        mockDatabase.insert(
          SettingsRepository.tableName,
          any as Map<String, Object?>,
        ),
      ).called(1);
    });

    test('setIntValue calls setSetting with int as string', () async {
      mockQueryResult([]);
      when(
        mockDatabase.insert(any as String, any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);
      await settingsRepository.setIntValue('int_setting', 678);
      verify(
        mockDatabase.insert(
          SettingsRepository.tableName,
          any as Map<String, Object?>,
        ),
      ).called(1);
    });

    test('setBoolValue calls setSetting with bool as string', () async {
      mockQueryResult([]);
      when(
        mockDatabase.insert(any as String, any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);
      await settingsRepository.setBoolValue('bool_setting', true);
      verify(
        mockDatabase.insert(
          SettingsRepository.tableName,
          any as Map<String, Object?>,
        ),
      ).called(1);
    });

    test('getAllSettings returns a list of settings', () async {
      mockQueryResult([
        {
          'key': 's1',
          'value': 'v1',
          'updated_at': DateTime.now().toIso8601String(),
        },
        {
          'key': 's2',
          'value': 'v2',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);

      final allSettings = await settingsRepository.getAllSettings();
      expect(allSettings.length, 2);
      expect(allSettings[0].key, 's1');
    });

    test('deleteSetting deletes a setting', () async {
      when(
        mockDatabase.delete(
          any as String,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs') as List<Object?>?,
        ),
      ).thenAnswer((_) async => 1);

      final rowsAffected = await settingsRepository.deleteSetting(
        'key_to_delete',
      );
      expect(rowsAffected, 1);
      verify(
        mockDatabase.delete(
          SettingsRepository.tableName,
          where: 'key = ?',
          whereArgs: ['key_to_delete'],
        ),
      ).called(1);
    });

    test('getGoldPrice returns gold price from settings', () async {
      mockQueryResult([
        {
          'key': SettingsKeys.goldPricePerGram,
          'value': '250.5',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);
      final price = await settingsRepository.getGoldPrice();
      expect(price, 250.5);
    });

    test('setGoldPrice sets gold price in settings', () async {
      mockQueryResult([]);
      when(
        mockDatabase.insert(any as String, any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);
      await settingsRepository.setGoldPrice(260.0);
      verify(
        mockDatabase.insert(
          SettingsRepository.tableName,
          any as Map<String, Object?>,
        ),
      ).called(1);
    });

    test('getSilverPrice returns silver price from settings', () async {
      mockQueryResult([
        {
          'key': SettingsKeys.silverPricePerGram,
          'value': '6.75',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);
      final price = await settingsRepository.getSilverPrice();
      expect(price, 6.75);
    });

    test('setSilverPrice sets silver price in settings', () async {
      mockQueryResult([]);
      when(
        mockDatabase.insert(any as String, any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);
      await settingsRepository.setSilverPrice(7.0);
      verify(
        mockDatabase.insert(
          SettingsRepository.tableName,
          any as Map<String, Object?>,
        ),
      ).called(1);
    });

    test('getStoreName returns store name from settings', () async {
      mockQueryResult([
        {
          'key': SettingsKeys.storeName,
          'value': 'My Awesome Store',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);
      final name = await settingsRepository.getStoreName();
      expect(name, 'My Awesome Store');
    });

    test('setStoreName sets store name in settings', () async {
      mockQueryResult([]);
      when(
        mockDatabase.insert(any as String, any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);
      await settingsRepository.setStoreName('New Store Name');
      verify(
        mockDatabase.insert(
          SettingsRepository.tableName,
          any as Map<String, Object?>,
        ),
      ).called(1);
    });

    test('getCurrency returns currency from settings', () async {
      mockQueryResult([
        {
          'key': SettingsKeys.currency,
          'value': 'USD',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);
      final currency = await settingsRepository.getCurrency();
      expect(currency, 'USD');
    });

    test('setCurrency sets currency in settings', () async {
      mockQueryResult([]);
      when(
        mockDatabase.insert(any as String, any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);
      await settingsRepository.setCurrency('EUR');
      verify(
        mockDatabase.insert(
          SettingsRepository.tableName,
          any as Map<String, Object?>,
        ),
      ).called(1);
    });

    test('getTaxRate returns tax rate from settings', () async {
      mockQueryResult([
        {
          'key': SettingsKeys.taxRate,
          'value': '0.05',
          'updated_at': DateTime.now().toIso8601String(),
        },
      ]);
      final rate = await settingsRepository.getTaxRate();
      expect(rate, 0.05);
    });

    test('setTaxRate sets tax rate in settings', () async {
      mockQueryResult([]);
      when(
        mockDatabase.insert(any as String, any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);
      await settingsRepository.setTaxRate(0.07);
      verify(
        mockDatabase.insert(
          SettingsRepository.tableName,
          any as Map<String, Object?>,
        ),
      ).called(1);
    });
  });
}
