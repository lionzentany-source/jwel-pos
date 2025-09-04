import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';

import '../models/invoice.dart';
import '../models/item.dart';
import '../models/customer.dart';
import '../repositories/material_repository.dart';
import '../models/material.dart' as app_mat;

/// # Report Service Implementation
///
/// This class provides functionality to export reports to PDF and Excel formats.
///
///
class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  /// Exports sales report to PDF
  Future<String> exportSalesReportToPDF({
    required List<Invoice> invoices,
    required DateTime startDate,
    required DateTime endDate,
    String? fileName,
  }) async {
    try {
      debugPrint("--- EXPORTING SALES REPORT TO PDF ---");

      // Create PDF document
      final pdf = pw.Document();

      // Calculate report statistics
      final totalSales = invoices.fold(
        0.0,
        (sum, invoice) => sum + invoice.total,
      );
      final totalInvoices = invoices.length;

      // Add report content
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                // Report header
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'تقرير المبيعات',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                // Report period
                pw.Text(
                  'لفترة من ${_formatDate(startDate)} إلى ${_formatDate(endDate)}',
                  style: pw.TextStyle(fontSize: 16),
                ),

                pw.SizedBox(height: 20),

                // Summary statistics
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'الإحصائيات العامة:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('إجمالي المبيعات: $totalSales د.ل'),
                      pw.Text('عدد الفواتير: $totalInvoices'),
                      pw.Text(
                        'متوسط الفاتورة: ${(totalSales / totalInvoices).toStringAsFixed(2)} د.ل',
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Invoices table
                pw.Text(
                  'تفاصيل الفواتير:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),

                pw.TableHelper.fromTextArray(
                  headers: ['رقم الفاتورة', 'التاريخ', 'العميل', 'الإجمالي'],
                  data: invoices
                      .map(
                        (invoice) => [
                          invoice.invoiceNumber,
                          _formatDate(invoice.createdAt),
                          invoice.customerId?.toString() ?? 'نقداً',
                          '${invoice.total.toStringAsFixed(2)} د.ل',
                        ],
                      )
                      .toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerRight,
                  cellStyle: pw.TextStyle(fontSize: 10),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to file
      final exportDir = await _getExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = fileName ?? 'sales_report_$timestamp';
      final pdfFileName = '$name.pdf';
      final pdfFilePath = path.join(exportDir.path, pdfFileName);

      final file = File(pdfFilePath);
      await file.writeAsBytes(await pdf.save());

      debugPrint("Sales report exported to PDF: $pdfFilePath");
      return pdfFilePath;
    } catch (e) {
      debugPrint("Error exporting sales report to PDF: $e");
      rethrow;
    }
  }

  /// Exports inventory report to PDF
  Future<String> exportInventoryReportToPDF({
    required List<Item> items,
    String? fileName,
    ItemLocation? filterLocation,
    bool groupByLocation = false,
  }) async {
    try {
      debugPrint("--- EXPORTING INVENTORY REPORT TO PDF ---");

      // Create PDF document
      final pdf = pw.Document();

      // Preload materials for price calculation
      final materials = await MaterialRepository().getAllMaterials();
      final Map<int, app_mat.Material> materialsById = {
        for (final m in materials)
          if (m.id != null) m.id!: m,
      };

      // Apply optional location filter
      final filteredItems = filterLocation == null
          ? items
          : items.where((i) => i.location == filterLocation).toList();

      // Calculate inventory statistics
      final totalItems = filteredItems.length;
      final inStockItems = filteredItems
          .where((item) => item.status == ItemStatus.inStock)
          .length;
      final soldItems = filteredItems
          .where((item) => item.status == ItemStatus.sold)
          .length;

      // Add report content
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                // Report header
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'تقرير المخزون',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                // Report date
                pw.Text(
                  'تاريخ التقرير: ${_formatDate(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 16),
                ),

                if (filterLocation != null)
                  pw.Text(
                    'نطاق المكان: ${filterLocation.displayName}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),

                pw.SizedBox(height: 20),

                // Summary statistics
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'الإحصائيات العامة:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('إجمالي الأصناف: $totalItems'),
                      pw.Text('في المخزون: $inStockItems'),
                      pw.Text('مباعة: $soldItems'),
                      pw.Text(
                        'تحتاج لبطاقة: ${items.where((item) => item.status == ItemStatus.needsRfid).length}',
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                if (!groupByLocation) ...[
                  pw.Text(
                    'تفاصيل الأصناف:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'رمز الصنف',
                      'الوزن',
                      'العيار',
                      'الحالة',
                      'المكان',
                      'السعر',
                    ],
                    data: filteredItems
                        .map(
                          (item) => [
                            item.sku,
                            '${item.weightGrams}g',
                            '${item.karat}K',
                            item.status.displayName,
                            item.location.displayName,
                            '${_calculateItemPrice(item, materialsById).toStringAsFixed(2)} د.ل',
                          ],
                        )
                        .toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    cellAlignment: pw.Alignment.centerRight,
                    cellStyle: pw.TextStyle(fontSize: 10),
                  ),
                ] else ...[
                  // Group by location sections
                  ...[ItemLocation.warehouse, ItemLocation.showroom]
                      .where(
                        (loc) =>
                            filterLocation == null || loc == filterLocation,
                      )
                      .map((loc) {
                        final locItems = filteredItems
                            .where((i) => i.location == loc)
                            .toList();
                        if (locItems.isEmpty) return pw.SizedBox();
                        return pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.SizedBox(height: 16),
                            pw.Text(
                              'المكان: ${loc.displayName} (${locItems.length})',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.TableHelper.fromTextArray(
                              headers: [
                                'رمز الصنف',
                                'الوزن',
                                'العيار',
                                'الحالة',
                                'السعر',
                              ],
                              data: locItems
                                  .map(
                                    (item) => [
                                      item.sku,
                                      '${item.weightGrams}g',
                                      '${item.karat}K',
                                      item.status.displayName,
                                      '${_calculateItemPrice(item, materialsById).toStringAsFixed(2)} د.ل',
                                    ],
                                  )
                                  .toList(),
                              headerStyle: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                              headerDecoration: pw.BoxDecoration(
                                color: PdfColors.grey300,
                              ),
                              cellAlignment: pw.Alignment.centerRight,
                              cellStyle: pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        );
                      }),
                ],
              ],
            );
          },
        ),
      );

      // Save PDF to file
      final exportDir = await _getExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = fileName ?? 'inventory_report_$timestamp';
      final pdfFileName = '$name.pdf';
      final pdfFilePath = path.join(exportDir.path, pdfFileName);

      final file = File(pdfFilePath);
      await file.writeAsBytes(await pdf.save());

      debugPrint("Inventory report exported to PDF: $pdfFilePath");
      return pdfFilePath;
    } catch (e) {
      debugPrint("Error exporting inventory report to PDF: $e");
      rethrow;
    }
  }

  /// Exports sales report to CSV
  Future<String> exportSalesReportToCSV({
    required List<Invoice> invoices,
    required DateTime startDate,
    required DateTime endDate,
    String? fileName,
  }) async {
    try {
      debugPrint("--- EXPORTING SALES REPORT TO CSV ---");

      final exportDir = await _getExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = fileName ?? 'sales_report_$timestamp';
      final csvFileName = '$name.csv';
      final csvFilePath = path.join(exportDir.path, csvFileName);

      final sink = File(csvFilePath).openWrite(encoding: utf8);
      // Header
      sink.writeln('Invoice Number,Date,Customer,Total');
      for (final invoice in invoices) {
        final number = invoice.invoiceNumber.toString();
        final date = _formatDate(invoice.createdAt);
        final customer = invoice.customerId?.toString() ?? 'Cash';
        final total = invoice.total.toStringAsFixed(2);
        sink.writeln('"$number","$date","$customer","$total"');
      }
      await sink.flush();
      await sink.close();

      debugPrint("Sales report exported to CSV: $csvFilePath");
      return csvFilePath;
    } catch (e) {
      debugPrint("Error exporting sales report to CSV: $e");
      rethrow;
    }
  }

  /// Exports customer report to PDF
  Future<String> exportCustomerReportToPDF({
    required List<Customer> customers,
    String? fileName,
  }) async {
    try {
      debugPrint("--- EXPORTING CUSTOMER REPORT TO PDF ---");

      // Create PDF document
      final pdf = pw.Document();

      // Calculate customer statistics
      final totalCustomers = customers.length;
      final activeCustomers = customers
          .where((customer) => customer.isActive)
          .length;

      // Add report content
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                // Report header
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'تقرير العملاء',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                // Report date
                pw.Text(
                  'تاريخ التقرير: ${_formatDate(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 16),
                ),

                pw.SizedBox(height: 20),

                // Summary statistics
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'الإحصائيات العامة:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('إجمالي العملاء: $totalCustomers'),
                      pw.Text('العملاء النشطين: $activeCustomers'),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Customers table
                pw.Text(
                  'تفاصيل العملاء:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),

                pw.TableHelper.fromTextArray(
                  headers: [
                    'الاسم',
                    'رقم الهاتف',
                    'البريد الإلكتروني',
                    'الحالة',
                  ],
                  data: customers
                      .map(
                        (customer) => [
                          customer.name,
                          customer.phone ?? 'غير متوفر',
                          customer.email ?? 'غير متوفر',
                          customer.isActive ? 'نشط' : 'غير نشط',
                        ],
                      )
                      .toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerRight,
                  cellStyle: pw.TextStyle(fontSize: 10),
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to file
      final exportDir = await _getExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = fileName ?? 'customer_report_$timestamp';
      final pdfFileName = '$name.pdf';
      final pdfFilePath = path.join(exportDir.path, pdfFileName);

      final file = File(pdfFilePath);
      await file.writeAsBytes(await pdf.save());

      debugPrint("Customer report exported to PDF: $pdfFilePath");
      return pdfFilePath;
    } catch (e) {
      debugPrint("Error exporting customer report to PDF: $e");
      rethrow;
    }
  }

  /// Exports report to Excel
  Future<String> exportToExcel({
    required String reportType,
    required List<dynamic> data,
    String? fileName,
  }) async {
    try {
      debugPrint("--- EXPORTING REPORT TO EXCEL ---");
      debugPrint("Report type: $reportType");

      final excel = Excel.createExcel();
      final sheet = excel[reportType];

      // Add headers based on report type
      if (reportType == 'Sales Report') {
        sheet.appendRow(['Invoice Number', 'Date', 'Customer', 'Total']);
        for (final invoice in data.cast<Invoice>()) {
          sheet.appendRow([
            invoice.invoiceNumber,
            _formatDate(invoice.createdAt),
            invoice.customerId?.toString() ?? 'Cash',
            invoice.total.toStringAsFixed(2),
          ]);
        }
      } else if (reportType == 'Inventory Report') {
        // Load materials for price calculation
        final materials = await MaterialRepository().getAllMaterials();
        final Map<int, app_mat.Material> materialsById = {
          for (final m in materials)
            if (m.id != null) m.id!: m,
        };
        sheet.appendRow([
          'SKU',
          'Weight (g)',
          'Karat',
          'Status',
          'Location',
          'Price',
        ]);
        for (final item in data.cast<Item>()) {
          sheet.appendRow([
            item.sku,
            item.weightGrams,
            item.karat,
            item.status.displayName,
            item.location.displayName,
            _calculateItemPrice(item, materialsById).toStringAsFixed(2),
          ]);
        }
      } else if (reportType == 'Customer Report') {
        sheet.appendRow(['Name', 'Phone', 'Email', 'Status']);
        for (final customer in data.cast<Customer>()) {
          sheet.appendRow([
            customer.name,
            customer.phone ?? 'N/A',
            customer.email ?? 'N/A',
            customer.isActive ? 'Active' : 'Inactive',
          ]);
        }
      } else {
        // Generic handling for unknown report types
        sheet.appendRow(['Data']);
        for (final item in data) {
          sheet.appendRow([item.toString()]);
        }
      }

      final exportDir = await _getExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name =
          fileName ?? '${reportType.replaceAll(' ', '_')}_report_$timestamp';
      final excelFileName = '$name.xlsx';
      final excelFilePath = path.join(exportDir.path, excelFileName);

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        await File(excelFilePath).writeAsBytes(fileBytes);
        debugPrint("Report exported to Excel: $excelFilePath");
        return excelFilePath;
      } else {
        throw Exception("Failed to encode Excel file.");
      }
    } catch (e) {
      debugPrint("Error exporting report to Excel: $e");
      rethrow;
    }
  }

  /// Gets export directory
  Future<Directory> _getExportDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(path.join(appDir.path, 'exports'));

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    return exportDir;
  }

  /// Formats date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Calculates item price using material price per gram when available
  double _calculateItemPrice(
    Item item,
    Map<int, app_mat.Material> materialsById,
  ) {
    final material = materialsById[item.materialId];
    final pricePerGram = (material != null && material.isVariable)
        ? material.pricePerGram
        : 0.0;
    final materialPrice = item.weightGrams * pricePerGram;
    return materialPrice + item.workmanshipFee + item.stonePrice;
  }
}
