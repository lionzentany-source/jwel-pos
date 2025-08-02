import '../models/invoice.dart';
import 'base_repository.dart';
import '../services/database_service.dart';
import '../models/cart_item.dart'; // For createSaleTransaction
import '../models/item.dart';

class InvoiceRepository extends BaseRepository<Invoice> {
  InvoiceRepository({DatabaseService? databaseService})
    : super(databaseService ?? DatabaseService(), 'invoices');

  @override
  Invoice fromMap(Map<String, dynamic> map) {
    return Invoice.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap(Invoice obj) {
    return obj.toMap();
  }

  Future<List<Invoice>> getAllInvoices() async {
    final maps = await super.query(orderBy: 'created_at DESC');
    return maps.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<Invoice?> getInvoiceById(int id) async {
    return await super.getById(id);
  }

  Future<int> insertInvoice(Invoice invoice) async {
    return await super.insert(invoice);
  }

  Future<int> updateInvoice(Invoice invoice) async {
    return await super.update(invoice);
  }

  Future<int> deleteInvoice(int id) async {
    return await super.delete(id);
  }

  // Specific invoice-related methods
  Future<int> createSaleTransaction(
    Invoice invoice,
    List<CartItem> items,
  ) async {
    final db = await database;
    return await db.transaction((txn) async {
      // إدراج الفاتورة
      final invoiceId = await txn.insert(tableName, toMap(invoice));
      // إدراج عناصر الفاتورة
      for (final cartItem in items) {
        if (cartItem.item.id == null) continue; // تأكد من وجود الصنف
        await txn.insert('invoice_items', {
          'invoice_id': invoiceId,
          'item_id': cartItem.item.id,
          'quantity': cartItem.quantity,
          'unit_price': cartItem.unitPrice,
          'total_price': cartItem.totalPrice,
        });
        // تحديث حالة الصنف إلى مباع
        await txn.update(
          'items',
          {
            'status': ItemStatus.sold.name,
            // مسح بطاقة RFID عند البيع لإعادة استخدامها مع صنف آخر
            'rfid_tag': null,
          },
          where: 'id = ?',
          whereArgs: [cartItem.item.id],
        );
      }
      return invoiceId;
    });
  }

  Future<List<CartItem>> getInvoiceCartItems(int invoiceId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT ii.quantity, ii.unit_price, ii.total_price, it.* FROM invoice_items ii
      JOIN items it ON it.id = ii.item_id
      WHERE ii.invoice_id = ?
    ''',
      [invoiceId],
    );
    final items = <CartItem>[];
    for (final row in result) {
      final item = Item.fromMap(row);
      items.add(
        CartItem(
          item: item,
          quantity: (row['quantity'] as num).toDouble(),
          unitPrice: (row['unit_price'] as num).toDouble(),
          discount: 0.0,
        ),
      );
    }
    return items;
  }

  Future<int> getTodayInvoiceCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final maps = await super.query(
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
    return maps.length;
  }

  Future<List<Map<String, dynamic>>> getSalesStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String? where;
    List<dynamic>? whereArgs;

    if (startDate != null && endDate != null) {
      where = 'created_at BETWEEN ? AND ?';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }

    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as totalInvoices, SUM(total) as totalSales, AVG(total) as averageSale, SUM(discount) as totalDiscounts FROM invoices${where != null ? ' WHERE $where' : ''}',
      whereArgs,
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> getTopSellingItems({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String? where;
    List<dynamic>? whereArgs;

    if (startDate != null && endDate != null) {
      where = 'i.created_at BETWEEN ? AND ?';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }

    final db = await database;
    final result = await db.rawQuery('''
        SELECT 
          it.sku as sku,
          it.weight_grams,
          it.karat,
          COUNT(*) as sales_count,
          SUM(ii.total_price) as total_revenue
        FROM invoice_items ii
        JOIN invoices i ON ii.invoice_id = i.id
        JOIN items it ON ii.item_id = it.id
        ${where != null ? 'WHERE $where' : ''}
        GROUP BY it.sku
        ORDER BY sales_count DESC
        LIMIT 10
        ''', whereArgs);
    return result;
  }

  Future<List<Invoice>> getInvoicesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final maps = await super.query(
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Invoice.fromMap(map)).toList();
  }
}
