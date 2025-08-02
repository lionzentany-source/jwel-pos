import '../models/invoice.dart';
import '../models/cart_item.dart';

import 'base_repository.dart';
import '../services/database_service.dart';

class InvoiceRepository extends BaseRepository {
  InvoiceRepository({DatabaseService? databaseService}) : super(databaseService ?? DatabaseService());
  static const String invoiceTableName = 'invoices';
  static const String invoiceItemsTableName = 'invoice_items';

  Future<List<Invoice>> getAllInvoices() async {
    final maps = await query(invoiceTableName, orderBy: 'created_at DESC');
    return maps.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<List<Invoice>> getInvoicesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final maps = await query(
      invoiceTableName,
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final maps = await query(
      invoiceTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Invoice.fromMap(maps.first);
    }
    return null;
  }

  Future<Invoice?> getInvoiceByNumber(String invoiceNumber) async {
    final maps = await query(
      invoiceTableName,
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Invoice.fromMap(maps.first);
    }
    return null;
  }

  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
    final maps = await query(
      invoiceItemsTableName,
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    return maps.map((map) => InvoiceItem.fromMap(map)).toList();
  }

  Future<int> insertInvoice(Invoice invoice) async {
    return await insert(invoiceTableName, invoice.toMap());
  }

  Future<int> insertInvoiceItem(InvoiceItem invoiceItem) async {
    return await insert(invoiceItemsTableName, invoiceItem.toMap());
  }

  // دالة لإنشاء بيع كامل مع معاملة آمنة
  Future<int> createSaleTransaction(
    Invoice invoice,
    List<CartItem> cartItems,
  ) async {
    return await transaction<int>((txn) async {
      // 1. إدراج الفاتورة
      final invoiceId = await txn.insert(invoiceTableName, invoice.toMap());

      // 2. إدراج عناصر الفاتورة وتحديث حالة الأصناف
      for (final cartItem in cartItems) {
        // إدراج عنصر الفاتورة
        final invoiceItem = InvoiceItem(
          invoiceId: invoiceId,
          itemId: cartItem.item.id!,
          quantity: cartItem.quantity,
          unitPrice: cartItem.unitPrice,
          totalPrice: cartItem.totalPrice,
        );

        await txn.insert(invoiceItemsTableName, invoiceItem.toMap());

        // تحديث حالة الصنف إلى "مباع"
        await txn.update(
          'items',
          {'status': 'sold'},
          where: 'id = ?',
          whereArgs: [cartItem.item.id],
        );
      }

      return invoiceId;
    });
  }

  Future<int> getTodayInvoiceCount() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await rawQuery(
      'SELECT COUNT(*) as count FROM $invoiceTableName WHERE created_at BETWEEN ? AND ?',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    return result.first['count'] as int;
  }

  Future<Map<String, dynamic>> getSalesStats(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = await rawQuery(
      '''
      SELECT 
        COUNT(*) as total_invoices,
        SUM(total) as total_sales,
        SUM(discount) as total_discounts,
        AVG(total) as average_sale
      FROM $invoiceTableName 
      WHERE created_at BETWEEN ? AND ?
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final row = result.first;
    return {
      'totalInvoices': row['total_invoices'] ?? 0,
      'totalSales': row['total_sales'] ?? 0.0,
      'totalDiscounts': row['total_discounts'] ?? 0.0,
      'averageSale': row['average_sale'] ?? 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getTopSellingItems(
    DateTime startDate,
    DateTime endDate, {
    int limit = 10,
  }) async {
    final result = await rawQuery(
      '''
      SELECT 
        i.sku,
        i.weight_grams,
        i.karat,
        COUNT(ii.item_id) as sales_count,
        SUM(ii.total_price) as total_revenue
      FROM invoice_items ii
      JOIN items i ON ii.item_id = i.id
      JOIN invoices inv ON ii.invoice_id = inv.id
      WHERE inv.created_at BETWEEN ? AND ?
      GROUP BY ii.item_id
      ORDER BY sales_count DESC
      LIMIT ?
    ''',
      [startDate.toIso8601String(), endDate.toIso8601String(), limit],
    );

    return result;
  }

  Future<int> updateInvoice(Invoice invoice) async {
    return await update(
      invoiceTableName,
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  Future<int> deleteInvoice(int id) async {
    return await transaction<int>((txn) async {
      // حذف عناصر الفاتورة أولاً
      await txn.delete(
        invoiceItemsTableName,
        where: 'invoice_id = ?',
        whereArgs: [id],
      );

      // ثم حذف الفاتورة
      return await txn.delete(
        invoiceTableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<bool> invoiceNumberExists(String invoiceNumber) async {
    final maps = await query(
      invoiceTableName,
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber],
      limit: 1,
    );
    return maps.isNotEmpty;
  }
}
