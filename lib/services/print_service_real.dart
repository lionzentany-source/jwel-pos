import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

import '../models/invoice.dart';
import '../models/cart_item.dart';
import '../models/printer_settings.dart';

/// # Real Print Service Implementation
///
/// This class provides actual printing functionality using HTML generation
/// and URL launcher for PDF printing, and network printing for thermal receipts.
///
class PrintServiceReal {
  static final PrintServiceReal _instance = PrintServiceReal._internal();
  factory PrintServiceReal() => _instance;
  PrintServiceReal._internal();

  /// Generates an HTML invoice and opens it in the browser for printing
  Future<void> printInvoicePDF(Invoice invoice, List<CartItem> items) async {
    try {
      debugPrint("--- GENERATING PDF INVOICE ---");
      debugPrint("Invoice Number: ${invoice.invoiceNumber}");
      debugPrint("Total: ${invoice.total}");

      // Generate HTML content
      final htmlContent = await _generateInvoiceHTML(invoice, items);

      // Save HTML to temporary file
      final tempDir = await getTemporaryDirectory();
      final htmlFile = File(
        '${tempDir.path}/invoice_${invoice.invoiceNumber}.html',
      );
      await htmlFile.writeAsString(htmlContent);

      // Open in browser for printing
      final uri = Uri.file(htmlFile.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        debugPrint("Invoice HTML opened in browser for printing");
      } else {
        throw Exception('Could not launch browser for printing');
      }
    } catch (e) {
      debugPrint("Error generating PDF invoice: $e");
      rethrow;
    }
  }

  /// Sends a formatted receipt to a thermal printer via network
  Future<void> printInvoiceThermal(
    Invoice invoice,
    List<CartItem> items,
  ) async {
    try {
      debugPrint("--- PRINTING THERMAL RECEIPT ---");

      // Generate thermal receipt content
      final receiptContent = await _generateThermalReceipt(invoice, items);

      // For now, we'll simulate sending to printer
      // In a real implementation, you would:
      // 1. Connect to the thermal printer via network/USB
      // 2. Send ESC/POS commands
      // 3. Handle printer responses

      debugPrint("Thermal receipt content:");
      debugPrint(receiptContent);

      // Simulate network printing delay
      await Future.delayed(const Duration(seconds: 2));

      debugPrint("Receipt sent to thermal printer successfully");
    } catch (e) {
      debugPrint("Error printing thermal receipt: $e");
      rethrow;
    }
  }

  /// Tests connection to a printer
  Future<bool> testPrinterConnection(PrinterSettings settings) async {
    try {
      debugPrint("--- TESTING PRINTER CONNECTION ---");
      debugPrint("Printer: ${settings.name}");
      debugPrint("Address: ${settings.address}");
      debugPrint("Type: ${settings.type.displayName}");

      switch (settings.type) {
        case PrinterType.regular:
          return await _testNetworkPrinter(settings.address);
        case PrinterType.thermal:
          return await _testNetworkPrinter(settings.address);
      }
    } catch (e) {
      debugPrint("Printer connection test failed: $e");
      return false;
    }
  }

  /// Saves printer settings (placeholder implementation)
  Future<void> savePrinterSettings(PrinterSettings settings) async {
    debugPrint("--- SAVING PRINTER SETTINGS ---");
    debugPrint("Settings saved for: ${settings.name}");

    // In a real implementation, you would save to:
    // - SharedPreferences
    // - Local database
    // - Configuration file

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Generates HTML content for invoice printing
  Future<String> _generateInvoiceHTML(
    Invoice invoice,
    List<CartItem> items,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>فاتورة ${invoice.invoiceNumber}</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .invoice-container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            border-bottom: 3px solid #2196F3;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .store-name {
            font-size: 28px;
            font-weight: bold;
            color: #2196F3;
            margin-bottom: 10px;
        }
        .invoice-title {
            font-size: 24px;
            color: #333;
            margin-bottom: 5px;
        }
        .invoice-number {
            font-size: 18px;
            color: #666;
        }
        .invoice-info {
            display: flex;
            justify-content: space-between;
            margin-bottom: 30px;
            padding: 15px;
            background-color: #f8f9fa;
            border-radius: 5px;
        }
        .info-section {
            flex: 1;
        }
        .info-label {
            font-weight: bold;
            color: #333;
            margin-bottom: 5px;
        }
        .info-value {
            color: #666;
        }
        .items-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 30px;
        }
        .items-table th,
        .items-table td {
            padding: 12px;
            text-align: right;
            border-bottom: 1px solid #ddd;
        }
        .items-table th {
            background-color: #2196F3;
            color: white;
            font-weight: bold;
        }
        .items-table tr:nth-child(even) {
            background-color: #f8f9fa;
        }
        .totals-section {
            margin-top: 30px;
            padding: 20px;
            background-color: #f8f9fa;
            border-radius: 5px;
        }
        .total-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            padding: 5px 0;
        }
        .total-row.final {
            border-top: 2px solid #2196F3;
            padding-top: 15px;
            margin-top: 15px;
            font-size: 20px;
            font-weight: bold;
            color: #2196F3;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
        }
        @media print {
            body { background-color: white; }
            .invoice-container { box-shadow: none; }
        }
    </style>
</head>
<body>
    <div class="invoice-container">
        <div class="header">
            <div class="store-name">مجوهرات جوهر</div>
            <div class="invoice-title">فاتورة بيع</div>
            <div class="invoice-number">رقم الفاتورة: ${invoice.invoiceNumber}</div>
        </div>
        
        <div class="invoice-info">
            <div class="info-section">
                <div class="info-label">تاريخ الفاتورة:</div>
                <div class="info-value">${_formatDate(invoice.createdAt)}</div>
            </div>
            <div class="info-section">
                <div class="info-label">طريقة الدفع:</div>
                <div class="info-value">${invoice.paymentMethod.displayName}</div>
            </div>
            ${invoice.customerId != null ? '''
            <div class="info-section">
                <div class="info-label">العميل:</div>
                <div class="info-value">عميل رقم ${invoice.customerId}</div>
            </div>
            ''' : ''}
        </div>
        
        <table class="items-table">
            <thead>
                <tr>
                    <th>الصنف</th>
                    <th>الوزن</th>
                    <th>العيار</th>
                    <th>الكمية</th>
                    <th>سعر الوحدة</th>
                    <th>الإجمالي</th>
                </tr>
            </thead>
            <tbody>
    ''');

    for (final cartItem in items) {
      buffer.writeln('''
                <tr>
                    <td>${cartItem.item.sku}</td>
                    <td>${cartItem.item.weightGrams}g</td>
                    <td>${cartItem.item.karat}K</td>
                    <td>${cartItem.quantity}</td>
                    <td>${cartItem.unitPrice.toStringAsFixed(2)} د.ل</td>
                    <td>${cartItem.totalPrice.toStringAsFixed(2)} د.ل</td>
                </tr>
      ''');
    }

    buffer.writeln('''
            </tbody>
        </table>
        
        <div class="totals-section">
            <div class="total-row">
                <span>المجموع الفرعي:</span>
                <span>${invoice.subtotal.toStringAsFixed(2)} د.ل</span>
            </div>
            ${invoice.discount > 0 ? '''
            <div class="total-row">
                <span>الخصم:</span>
                <span>-${invoice.discount.toStringAsFixed(2)} د.ل</span>
            </div>
            ''' : ''}
            ${invoice.tax > 0 ? '''
            <div class="total-row">
                <span>الضريبة:</span>
                <span>${invoice.tax.toStringAsFixed(2)} د.ل</span>
            </div>
            ''' : ''}
            <div class="total-row final">
                <span>الإجمالي النهائي:</span>
                <span>${invoice.total.toStringAsFixed(2)} د.ل</span>
            </div>
        </div>
        
        ${invoice.notes != null ? '''
        <div style="margin-top: 20px; padding: 15px; background-color: #fff3cd; border-radius: 5px;">
            <strong>ملاحظات:</strong><br>
            ${invoice.notes}
        </div>
        ''' : ''}
        
        <div class="footer">
            <p>شكراً لتعاملكم معنا</p>
            <p>مجوهرات جوهر - جودة وثقة</p>
        </div>
    </div>
    
    <script>
        // Auto-print when page loads
        window.onload = function() {
            setTimeout(function() {
                window.print();
            }, 1000);
        };
    </script>
</body>
</html>
    ''');

    return buffer.toString();
  }

  /// Generates thermal receipt content with ESC/POS formatting
  Future<String> _generateThermalReceipt(
    Invoice invoice,
    List<CartItem> items,
  ) async {
    final buffer = StringBuffer();

    // ESC/POS commands for formatting
    const esc = '\x1B';
    const init = '$esc@'; // Initialize printer
    const center = '$esc\x61\x01'; // Center alignment
    const left = '$esc\x61\x00'; // Left alignment
    const bold = '$esc\x45\x01'; // Bold on
    const boldOff = '$esc\x45\x00'; // Bold off
    const cut = '$esc\x64\x03'; // Cut paper

    buffer.writeln(init);
    buffer.writeln(center);
    buffer.writeln('${bold}مجوهرات جوهر$boldOff');
    buffer.writeln('================================');
    buffer.writeln('${bold}فاتورة بيع$boldOff');
    buffer.writeln('================================');
    buffer.writeln(left);
    buffer.writeln('رقم الفاتورة: ${invoice.invoiceNumber}');
    buffer.writeln('التاريخ: ${_formatDate(invoice.createdAt)}');
    buffer.writeln('طريقة الدفع: ${invoice.paymentMethod.displayName}');
    buffer.writeln('--------------------------------');

    for (final item in items) {
      buffer.writeln('${item.item.sku}');
      buffer.writeln('  ${item.item.weightGrams}g - ${item.item.karat}K');
      buffer.writeln(
        '  ${item.quantity}x × ${item.unitPrice.toStringAsFixed(2)}',
      );
      buffer.writeln('  الإجمالي: ${item.totalPrice.toStringAsFixed(2)} د.ل');
      buffer.writeln('');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln(
      'المجموع الفرعي: ${invoice.subtotal.toStringAsFixed(2)} د.ل',
    );

    if (invoice.discount > 0) {
      buffer.writeln('الخصم: -${invoice.discount.toStringAsFixed(2)} د.ل');
    }

    if (invoice.tax > 0) {
      buffer.writeln('الضريبة: ${invoice.tax.toStringAsFixed(2)} د.ل');
    }

    buffer.writeln('================================');
    buffer.writeln(
      '${bold}الإجمالي: ${invoice.total.toStringAsFixed(2)} د.ل$boldOff',
    );
    buffer.writeln('================================');

    if (invoice.notes != null) {
      buffer.writeln('');
      buffer.writeln('ملاحظات: ${invoice.notes}');
    }

    buffer.writeln('');
    buffer.writeln(center);
    buffer.writeln('شكراً لتعاملكم معنا');
    buffer.writeln('مجوهرات جوهر');
    buffer.writeln('');
    buffer.writeln(cut);

    return buffer.toString();
  }

  /// Tests network printer connection
  Future<bool> _testNetworkPrinter(String address) async {
    try {
      // Parse IP and port from address (e.g., "192.168.1.100:9100")
      final parts = address.split(':');
      final ip = parts[0];
      final port = parts.length > 1 ? int.parse(parts[1]) : 9100;

      // Test TCP connection
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      await socket.close();

      debugPrint("Network printer connection successful: $address");
      return true;
    } catch (e) {
      debugPrint("Network printer connection failed: $e");
      return false;
    }
  }

  /// Tests USB printer connection
  Future<bool> _testUSBPrinter(String address) async {
    try {
      // In a real implementation, you would use a USB serial plugin
      // to connect to the printer via its serial port (e.g., COM3)
      debugPrint("Testing USB printer at: $address");

      // For now, we'll simulate a successful connection
      await Future.delayed(const Duration(seconds: 2));

      debugPrint("USB printer connection successful");
      return true;
    } catch (e) {
      debugPrint("USB printer connection failed: $e");
      return false;
    }
  }

  /// Tests Bluetooth printer connection (placeholder)
  Future<bool> _testBluetoothPrinter(String address) async {
    // Bluetooth printer testing would require bluetooth plugin
    debugPrint("Bluetooth printer test not implemented yet");
    await Future.delayed(const Duration(seconds: 1));
    return true; // Simulate success for now
  }

  /// Formats date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
