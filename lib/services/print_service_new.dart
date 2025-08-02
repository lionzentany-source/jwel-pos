import 'package:flutter/foundation.dart';
import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

import '../models/invoice_render_data.dart';
import '../utils/invoice_html_builder.dart';

class PrintServiceNew {
  static final PrintServiceNew _instance = PrintServiceNew._internal();
  factory PrintServiceNew() => _instance;
  PrintServiceNew._internal();

  // دعم USB غير متوفر حالياً في الحزم الحديثة
  // إذا أردت دعم USB، استخدم مكتبة متخصصة أو أضف منطقك الخاص

  Future<void> initBluetooth() async {
    if (!kIsWeb) {
      BluetoothPrintPlus.startScan(timeout: const Duration(seconds: 4));
    }
  }

  Stream<List<BluetoothDevice>> get bluetoothDevices =>
      BluetoothPrintPlus.scanResults;

  Future<bool> connectBluetooth(BluetoothDevice device) async {
    return await BluetoothPrintPlus.connect(device);
  }

  Future<bool> disconnectBluetooth() async {
    return await BluetoothPrintPlus.disconnect();
  }

  Future<void> printBluetooth(Uint8List data) async {
    // يجب توليد أمر ESC/POS أو TSC أو CPCL حسب نوع الطابعة
    // مثال: BluetoothPrintPlus.write(cmd);
    // هنا cmd هو Uint8List يمثل أمر الطباعة
    // ستحتاج لتوليد cmd باستخدام مكتبة esc_pos_utils_plus أو غيرها
    // BluetoothPrintPlus.write(data);
    BluetoothPrintPlus.write(data);
  }

  // جميع دوال USB أدناه غير مدعومة حالياً
  // Future<void> printUsb(Uint8List data) async {
  //   debugPrint("USB printing is not supported in the current implementation.");
  // }

  Future<List<int>> generateThermalReceipt(InvoiceRenderData data) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    bytes += generator.text(
      data.storeName,
      styles: PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'فاتورة بيع',
      styles: PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'رقم: ${data.invoiceNumber}',
      styles: PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'التاريخ: ${_formatDate(data.date)}',
      styles: PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'الصنف', width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: 'كم', width: 2, styles: PosStyles(bold: true)),
      PosColumn(text: 'سعر', width: 3, styles: PosStyles(bold: true)),
      PosColumn(text: 'إجمالي', width: 3, styles: PosStyles(bold: true)),
    ]);
    bytes += generator.hr();
    for (final it in data.items) {
      bytes += generator.row([
        PosColumn(text: _trim(it.item.sku, 10), width: 4),
        PosColumn(
          text: it.quantity.toStringAsFixed(0),
          width: 2,
          styles: PosStyles(align: PosAlign.center),
        ),
        PosColumn(text: it.unitPrice.toStringAsFixed(2), width: 3),
        PosColumn(text: it.totalPrice.toStringAsFixed(2), width: 3),
      ]);
    }
    bytes += generator.hr();
    bytes += generator.text(
      'المجموع الفرعي: ${data.subtotal.toStringAsFixed(2)}',
    );
    if (data.discount > 0) {
      bytes += generator.text('الخصم: -${data.discount.toStringAsFixed(2)}');
    }
    if (data.tax > 0) {
      bytes += generator.text('الضريبة: ${data.tax.toStringAsFixed(2)}');
    }
    bytes += generator.text(
      'الإجمالي: ${data.total.toStringAsFixed(2)}',
      styles: PosStyles(bold: true),
    );
    if (data.notes != null && data.notes!.isNotEmpty) {
      bytes += generator.feed(1);
      bytes += generator.text('ملاحظات:');
      bytes += generator.text(_trim(data.notes!, 40));
    }
    bytes += generator.feed(1);
    bytes += generator.text(
      'شكراً لزيارتكم',
      styles: PosStyles(align: PosAlign.center),
    );
    bytes += generator.cut();
    return bytes;
  }

  String _trim(String v, int max) => v.length <= max ? v : v.substring(0, max);

  Future<void> printInvoiceHTMLFromData(InvoiceRenderData data) async {
    try {
      debugPrint("--- GENERATING HTML INVOICE (unified) ---");
      debugPrint("Invoice Number: ${data.invoiceNumber}");
      debugPrint("Total: ${data.total}");

      final htmlContent = buildInvoiceHtml(data);

      // Save HTML to temporary file
      final tempDir = await getTemporaryDirectory();
      final htmlFile = File(
        '${tempDir.path}/invoice_${data.invoiceNumber}.html',
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
      debugPrint("Error generating HTML invoice: $e");
      rethrow;
    }
  }
  // Deprecated _generateInvoiceHTML removed; unified builder used

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
