import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwe_pos/repositories/customer_repository.dart';
import 'package:jwe_pos/models/customer.dart';
import 'package:jwe_pos/services/database_service.dart';

// Mock classes
class MockDatabase extends Mock implements Database {}

class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  group('CustomerRepository', () {
    late CustomerRepository customerRepository;
    late MockDatabase mockDatabase;
    late MockDatabaseService mockDatabaseService;

    setUp(() {
      DatabaseService.resetForTesting();
      mockDatabase = MockDatabase();
      mockDatabaseService = MockDatabaseService();
      when(mockDatabaseService.database).thenAnswer((_) async => mockDatabase);
      DatabaseService.testInstance = mockDatabaseService;
      customerRepository = CustomerRepository(
        databaseService: mockDatabaseService,
      );
    });

    tearDown(() {
      DatabaseService.resetForTesting();
    });

    void mockQueryResult(List<Map<String, dynamic>> result) {
      when(
        mockDatabase.query(
          'customers',
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
          'SELECT COUNT(*) as count FROM invoices WHERE customer_id = ?',
          [any],
        ),
      ).thenAnswer((_) async => result);
    }

    test('getAllCustomers returns a list of customers', () async {
      mockQueryResult([
        {
          'id': 1,
          'name': 'أحمد محمد',
          'phone': '123456789',
          'email': 'ahmed@example.com',
          'address': 'الرياض',
        },
        {
          'id': 2,
          'name': 'فاطمة علي',
          'phone': '987654321',
          'email': 'fatima@example.com',
          'address': 'جدة',
        },
      ]);

      final customers = await customerRepository.getAllCustomers();
      expect(customers.length, 2);
      expect(customers[0].name, 'أحمد محمد');
      expect(customers[1].name, 'فاطمة علي');
    });

    test('getCustomerById returns a customer if found', () async {
      mockQueryResult([
        {
          'id': 1,
          'name': 'أحمد محمد',
          'phone': '123456789',
          'email': 'ahmed@example.com',
          'address': 'الرياض',
        },
      ]);

      final customer = await customerRepository.getCustomerById(1);
      expect(customer, isNotNull);
      expect(customer?.id, 1);
      expect(customer?.name, 'أحمد محمد');
    });

    test('getCustomerById returns null if not found', () async {
      mockQueryResult([]);

      final customer = await customerRepository.getCustomerById(99);
      expect(customer, isNull);
    });

    test('insertCustomer inserts a customer and returns its id', () async {
      when(
        mockDatabase.insert('customers', any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);

      final customer = Customer(
        name: 'عميل جديد',
        phone: '555666777',
        email: 'new@example.com',
        address: 'الدمام',
      );
      final id = await customerRepository.insertCustomer(customer);
      expect(id, 1);
      verify(
        mockDatabase.insert('customers', any as Map<String, Object?>),
      ).called(1);
    });

    test(
      'updateCustomer updates a customer and returns number of rows affected',
      () async {
        when(
          mockDatabase.update(
            'customers',
            any as Map<String, Object?>,
            where: anyNamed('where'),
            whereArgs: anyNamed('whereArgs'),
          ),
        ).thenAnswer((_) async => 1);

        final customer = Customer(
          id: 1,
          name: 'عميل محدث',
          phone: '111222333',
          email: 'updated@example.com',
          address: 'مكة',
        );
        final rowsAffected = await customerRepository.updateCustomer(customer);
        expect(rowsAffected, 1);
        verify(
          mockDatabase.update(
            'customers',
            any as Map<String, Object?>,
            where: 'id = ?',
            whereArgs: [1],
          ),
        ).called(1);
      },
    );

    test(
      'deleteCustomer deletes a customer and returns number of rows affected',
      () async {
        mockRawQueryResult([
          {'count': 0},
        ]); // No invoices associated
        when(
          mockDatabase.delete(
            'customers',
            where: anyNamed('where'),
            whereArgs: anyNamed('whereArgs'),
          ),
        ).thenAnswer((_) async => 1);

        final rowsAffected = await customerRepository.deleteCustomer(1);
        expect(rowsAffected, 1);
        verify(
          mockDatabase.delete('customers', where: 'id = ?', whereArgs: [1]),
        ).called(1);
      },
    );

    test(
      'deleteCustomer throws exception if customer has associated invoices',
      () async {
        mockRawQueryResult([
          {'count': 3},
        ]); // Has associated invoices

        expect(() => customerRepository.deleteCustomer(1), throwsException);
      },
    );

    test('searchCustomers returns filtered customers', () async {
      mockQueryResult([
        {
          'id': 1,
          'name': 'أحمد محمد',
          'phone': '123456789',
          'email': 'ahmed@example.com',
          'address': 'الرياض',
        },
      ]);

      final customers = await customerRepository.searchCustomers('أحمد');
      expect(customers.length, 1);
      expect(customers[0].name, 'أحمد محمد');
    });
  });
}
