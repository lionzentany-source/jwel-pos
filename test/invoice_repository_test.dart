import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jwe_pos/repositories/invoice_repository.dart';
import 'package:jwe_pos/models/invoice.dart';
import 'package:jwe_pos/services/database_service.dart';

// Mock classes
class MockDatabase extends Mock implements Database {}

class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  group('InvoiceRepository', () {
    late InvoiceRepository invoiceRepository;
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
      invoiceRepository = InvoiceRepository(
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

    void mockRawQueryResult(List<Map<String, dynamic>> result) {
      when(
        mockDatabase.rawQuery(any as String, any as List<Object?>?),
      ).thenAnswer((_) async => result);
    }

    test('getAllInvoices returns a list of invoices', () async {
      mockQueryResult([
        {
          'id': 1,
          'invoice_number': 'INV001',
          'customer_id': 1,
          'total': 100.0,
          'discount': 0.0,
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);

      final invoices = await invoiceRepository.getAllInvoices();
      expect(invoices.length, 1);
      expect(invoices[0].invoiceNumber, 'INV001');
    });

    test('getInvoiceById returns an invoice if found', () async {
      mockQueryResult([
        {
          'id': 1,
          'invoice_number': 'INV001',
          'customer_id': 1,
          'total': 100.0,
          'discount': 0.0,
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);

      final invoice = await invoiceRepository.getInvoiceById(1);
      expect(invoice, isNotNull);
      expect(invoice?.id, 1);
    });

    test('getInvoiceById returns null if not found', () async {
      mockQueryResult([]);

      final invoice = await invoiceRepository.getInvoiceById(99);
      expect(invoice, isNull);
    });

    test('insertInvoice inserts an invoice and returns its id', () async {
      when(
        mockDatabase.insert(any as String, any as Map<String, Object?>),
      ).thenAnswer((_) async => 1);

      final invoice = Invoice(
        invoiceNumber: 'NEWINV',
        customerId: 1,
        subtotal: 50.0,
        total: 50.0,
        paymentMethod: PaymentMethod.cash,
        userId: 1,
      );
      final id = await invoiceRepository.insertInvoice(invoice);
      expect(id, 1);
      verify(
        mockDatabase.insert(
          InvoiceRepository.invoiceTableName,
          any as Map<String, Object?>,
        ),
      ).called(1);
    });

    test('getTodayInvoiceCount returns correct count', () async {
      mockRawQueryResult([
        {'count': 5},
      ]);

      final count = await invoiceRepository.getTodayInvoiceCount();
      expect(count, 5);
    });

    test('getSalesStats returns correct stats', () async {
      mockRawQueryResult([
        {
          'total_invoices': 10,
          'total_sales': 1000.0,
          'total_discounts': 50.0,
          'average_sale': 100.0,
        },
      ]);

      final stats = await invoiceRepository.getSalesStats(
        DateTime.now(),
        DateTime.now(),
      );
      expect(stats['totalInvoices'], 10);
      expect(stats['totalSales'], 1000.0);
      expect(stats['totalDiscounts'], 50.0);
      expect(stats['averageSale'], 100.0);
    });

    test('getTopSellingItems returns correct items', () async {
      mockRawQueryResult([
        {'sku': 'SKU001', 'sales_count': 5, 'total_revenue': 500.0},
        {'sku': 'SKU002', 'sales_count': 3, 'total_revenue': 150.0},
      ]);

      final items = await invoiceRepository.getTopSellingItems(
        DateTime.now(),
        DateTime.now(),
      );
      expect(items.length, 2);
      expect(items[0]['sku'], 'SKU001');
    });

    test(
      'updateInvoice updates an invoice and returns number of rows affected',
      () async {
        when(
          mockDatabase.update(
            any as String,
            any as Map<String, Object?>,
            where: anyNamed('where'),
            whereArgs: anyNamed('whereArgs') as List<Object?>?,
          ),
        ).thenAnswer((_) async => 1);

        final invoice = Invoice(
          id: 1,
          invoiceNumber: 'UPDATEDINV',
          customerId: 1,
          subtotal: 120.0,
          total: 120.0,
          paymentMethod: PaymentMethod.cash,
          userId: 1,
        );
        final rowsAffected = await invoiceRepository.updateInvoice(invoice);
        expect(rowsAffected, 1);
        verify(
          mockDatabase.update(
            InvoiceRepository.invoiceTableName,
            any as Map<String, Object?>,
            where: 'id = ?',
            whereArgs: [1],
          ),
        ).called(1);
      },
    );

    test('invoiceNumberExists returns true if invoice number exists', () async {
      mockQueryResult([
        {
          'id': 1,
          'invoice_number': 'EXISTINGINV',
          'customer_id': 1,
          'total': 100.0,
          'discount': 0.0,
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);

      final exists = await invoiceRepository.invoiceNumberExists('EXISTINGINV');
      expect(exists, isTrue);
    });

    test(
      'invoiceNumberExists returns false if invoice number does not exist',
      () async {
        mockQueryResult([]);

        final exists = await invoiceRepository.invoiceNumberExists(
          'NONEXISTENTINV',
        );
        expect(exists, isFalse);
      },
    );
  });
}
