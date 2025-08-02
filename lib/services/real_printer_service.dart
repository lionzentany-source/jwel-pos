import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

class RealPrinterService {
  static final RealPrinterService _instance = RealPrinterService._internal();
  factory RealPrinterService() => _instance;
  RealPrinterService._internal();

  /// الحصول على قائمة الطابعات المتاحة في النظام
  Future<List<Printer>> getAvailablePrinters() async {
    try {
      debugPrint('🖨️ بدء البحث عن الطابعات...');

      // أولاً: محاولة الحصول على الطابعات باستخدام Flutter printing
      List<Printer> printers = [];
      try {
        printers = await Printing.listPrinters().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⏰ انتهت مهلة البحث عن الطابعات');
            return <Printer>[];
          },
        );
      } catch (e) {
        debugPrint('⚠️ فشل في استخدام Printing.listPrinters(): $e');
      }

      // ثانياً: إذا لم نجد طابعات، جرب أوامر Windows
      if (printers.isEmpty && Platform.isWindows) {
        debugPrint('🔍 محاولة البحث باستخدام أوامر Windows...');
        await _checkWindowsPrinters();
      }

      debugPrint('📊 تم العثور على ${printers.length} طابعة');

      if (printers.isEmpty) {
        debugPrint('❌ لم يتم العثور على طابعات. التحقق من:');
        debugPrint('   - تأكد من تشغيل الطابعة');
        debugPrint('   - تأكد من توصيل الطابعة بالكمبيوتر');
        debugPrint('   - تأكد من تثبيت برامج تشغيل الطابعة');
        debugPrint('   - تحقق من إعدادات Windows للطابعات');
        debugPrint('   - جرب إعادة تشغيل خدمة Print Spooler');
      } else {
        for (int i = 0; i < printers.length; i++) {
          final printer = printers[i];
          debugPrint('🖨️ طابعة ${i + 1}:');
          debugPrint('   الاسم: ${printer.name}');
          debugPrint('   الرابط: ${printer.url}');
          debugPrint('   افتراضية: ${printer.isDefault ? 'نعم' : 'لا'}');
          debugPrint('   متاحة: ${printer.isAvailable ? 'نعم' : 'لا'}');
        }
      }

      return printers;
    } catch (e, stackTrace) {
      debugPrint('❌ خطأ في الحصول على الطابعات: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return [];
    }
  }

  /// فحص طابعات Windows باستخدام أوامر النظام
  Future<void> _checkWindowsPrinters() async {
    try {
      debugPrint('💻 فحص طابعات Windows...');

      // أولاً: فحص حالة خدمة Print Spooler
      await _checkPrintSpoolerService();

      // استخدام أمر wmic للحصول على معلومات الطابعات
      final result = await Process.run('wmic', [
        'printer',
        'get',
        'name,default,status',
      ], runInShell: true);

      if (result.exitCode == 0) {
        debugPrint('📋 نتائج أمر wmic:');
        debugPrint(result.stdout.toString());
      } else {
        debugPrint('❌ فشل أمر wmic: ${result.stderr}');
      }

      // جرب أيضاً أمر PowerShell
      final psResult = await Process.run('powershell', [
        '-Command',
        'Get-Printer | Select-Object Name, PrinterStatus, Default',
      ], runInShell: true);

      if (psResult.exitCode == 0) {
        debugPrint('📋 نتائج PowerShell:');
        debugPrint(psResult.stdout.toString());
      } else {
        debugPrint('❌ فشل أمر PowerShell: ${psResult.stderr}');
        if (psResult.stderr.toString().contains('spooler service')) {
          debugPrint('⚠️ خدمة Print Spooler غير مشغلة!');
          await _startPrintSpoolerService();
        }
      }
    } catch (e) {
      debugPrint('❌ خطأ في فحص طابعات Windows: $e');
    }
  }

  /// فحص حالة خدمة Print Spooler
  Future<void> _checkPrintSpoolerService() async {
    try {
      debugPrint('🔍 فحص حالة خدمة Print Spooler...');

      final result = await Process.run('sc', [
        'query',
        'spooler',
      ], runInShell: true);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        debugPrint('📋 حالة خدمة Print Spooler:');
        debugPrint(output);

        if (output.contains('STOPPED')) {
          debugPrint('⚠️ خدمة Print Spooler متوقفة. محاولة تشغيلها...');
          await _startPrintSpoolerService();
        } else if (output.contains('RUNNING')) {
          debugPrint('✅ خدمة Print Spooler تعمل بشكل طبيعي');
        }
      } else {
        debugPrint('❌ فشل في فحص خدمة Print Spooler: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('❌ خطأ في فحص خدمة Print Spooler: $e');
    }
  }

  /// تشغيل خدمة Print Spooler
  Future<void> _startPrintSpoolerService() async {
    try {
      debugPrint('🚀 محاولة تشغيل خدمة Print Spooler...');

      // الطريقة الأولى: net start
      var result = await Process.run('net', [
        'start',
        'spooler',
      ], runInShell: true);

      if (result.exitCode == 0) {
        debugPrint('✅ تم تشغيل خدمة Print Spooler بنجاح!');
        await Future.delayed(const Duration(seconds: 2));
        return;
      }

      debugPrint('⚠️ فشلت الطريقة الأولى، جاري المحاولة بطريقة أخرى...');

      // الطريقة الثانية: sc start
      result = await Process.run('sc', ['start', 'spooler'], runInShell: true);

      if (result.exitCode == 0) {
        debugPrint('✅ تم تشغيل خدمة Print Spooler بالطريقة الثانية!');
        await Future.delayed(const Duration(seconds: 2));
        return;
      }

      debugPrint('⚠️ فشلت الطريقة الثانية، جاري إصلاح الخدمة...');
      await _repairPrintSpooler();
    } catch (e) {
      debugPrint('❌ خطأ في تشغيل خدمة Print Spooler: $e');
      await _showPrintSpoolerInstructions();
    }
  }

  /// إصلاح خدمة Print Spooler
  Future<void> _repairPrintSpooler() async {
    try {
      debugPrint('🔧 محاولة إصلاح خدمة Print Spooler...');

      // إيقاف الخدمة أولاً
      await Process.run('net', ['stop', 'spooler'], runInShell: true);
      await Future.delayed(const Duration(seconds: 1));

      // مسح ملفات الطباعة المعلقة
      debugPrint('🗑️ مسح ملفات الطباعة المعلقة...');
      try {
        final spoolDir = Directory(r'C:\Windows\System32\spool\PRINTERS');
        if (await spoolDir.exists()) {
          await for (final file in spoolDir.list()) {
            if (file is File) {
              try {
                await file.delete();
              } catch (e) {
                // تجاهل الأخطاء في حذف الملفات
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ لم يتمكن من مسح ملفات الطباعة: $e');
      }

      // إعادة تشغيل الخدمة
      await Future.delayed(const Duration(seconds: 2));
      final result = await Process.run('net', [
        'start',
        'spooler',
      ], runInShell: true);

      if (result.exitCode == 0) {
        debugPrint('✅ تم إصلاح وتشغيل خدمة Print Spooler!');
      } else {
        await _showPrintSpoolerInstructions();
      }
    } catch (e) {
      debugPrint('❌ فشل في إصلاح خدمة Print Spooler: $e');
      await _showPrintSpoolerInstructions();
    }
  }

  /// عرض تعليمات إصلاح Print Spooler
  Future<void> _showPrintSpoolerInstructions() async {
    debugPrint('📋 تعليمات إصلاح خدمة Print Spooler:');
    debugPrint('1️⃣ افتح Command Prompt كمدير (Run as Administrator)');
    debugPrint('2️⃣ نفذ الأوامر التالية بالترتيب:');
    debugPrint('   net stop spooler');
    debugPrint('   del /Q /F C:\\Windows\\System32\\spool\\PRINTERS\\*');
    debugPrint('   net start spooler');
    debugPrint('3️⃣ أو من Services.msc:');
    debugPrint('   - اضغط Win+R واكتب services.msc');
    debugPrint('   - ابحث عن Print Spooler');
    debugPrint('   - انقر بالزر الأيمن واختر Properties');
    debugPrint('   - اضبط Startup type على Automatic');
    debugPrint('   - اضغط Start');
    debugPrint('4️⃣ إذا استمرت المشكلة، جرب:');
    debugPrint('   sfc /scannow');
    debugPrint('   DISM /Online /Cleanup-Image /RestoreHealth');
  }

  /// اختبار الطباعة على طابعة محددة
  Future<bool> testPrint(Printer printer) async {
    try {
      debugPrint('🖨️ بدء اختبار الطباعة على: ${printer.name}');

      final testContent = await _generateTestPage();

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async {
          debugPrint(
            '📄 تم إنشاء محتوى الاختبار بحجم: ${testContent.length} بايت',
          );
          return testContent;
        },
      );

      debugPrint('✅ تم إرسال صفحة الاختبار بنجاح للطابعة: ${printer.name}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ خطأ في طباعة الاختبار على ${printer.name}: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      return false;
    }
  }

  /// طباعة فاتورة على طابعة محددة
  Future<bool> printInvoice(
    Printer printer,
    Map<String, dynamic> invoiceData,
  ) async {
    try {
      final invoiceContent = _generateInvoicePdf(invoiceData);
      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) => invoiceContent,
      );
      debugPrint('تم طباعة الفاتورة على: ${printer.name}');
      return true;
    } catch (e) {
      debugPrint('خطأ في طباعة الفاتورة: $e');
      return false;
    }
  }

  // نسخة جديدة تعتمد على InvoiceRenderData مستقبلاً (للتكامل مع الواجهة الموحدة)
  // TODO: استبدال جميع الاستدعاءات الخارجية بهذه الدالة ثم إزالة نسخة الخريطة القديمة.

  /// الحصول على الطابعة الافتراضية
  Future<Printer?> getDefaultPrinter() async {
    try {
      debugPrint('🔍 البحث عن الطابعة الافتراضية...');
      final printers = await getAvailablePrinters();

      if (printers.isEmpty) {
        debugPrint('❌ لا توجد طابعات متاحة');
        return null;
      }

      // البحث عن الطابعة الافتراضية
      Printer? defaultPrinter;
      try {
        defaultPrinter = printers.firstWhere((printer) => printer.isDefault);
        debugPrint(
          '✅ تم العثور على الطابعة الافتراضية: ${defaultPrinter.name}',
        );
      } catch (e) {
        // إذا لم توجد طابعة افتراضية، استخدم الأولى
        defaultPrinter = printers.first;
        debugPrint(
          '⚠️ لا توجد طابعة افتراضية، استخدام الأولى: ${defaultPrinter.name}',
        );
      }

      return defaultPrinter;
    } catch (e) {
      debugPrint('❌ خطأ في الحصول على الطابعة الافتراضية: $e');
      return null;
    }
  }

  /// توليد صفحة اختبار
  Future<pw.Font> _loadArabicFont() async {
    try {
      final data = await rootBundle.load(
        'assets/fonts/NotoSansArabic-Regular.ttf',
      );
      return pw.Font.ttf(data);
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  Future<Uint8List> _generateTestPage() async {
    final pdf = pw.Document();
    final arabicFont = await _loadArabicFont();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          (80 / 25.4) * PdfPageFormat.inch,
          (210 / 25.4) * PdfPageFormat.inch,
        ),
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          // استخدام هوامش داخلية أصغر (حواف شبه صفر) لزيادة المساحة الفعلية للطباعة
          return pw.Padding(
            padding: const pw.EdgeInsets.all(2),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'صفحة اختبار الطباعة',
                  style: pw.TextStyle(
                    font: arabicFont,
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'نظام جوهر - نظام إدارة المجوهرات',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'تاريخ الاختبار: ${DateTime.now().toString().split('.')[0]}',
                        style: pw.TextStyle(font: arabicFont),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'هذه صفحة اختبار للتأكد من عمل الطابعة بشكل صحيح',
                        style: pw.TextStyle(font: arabicFont),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'إذا كنت تقرأ هذا النص، فإن الطابعة تعمل بشكل صحيح!',
                  style: pw.TextStyle(font: arabicFont),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// توليد PDF للفاتورة
  Future<Uint8List> _generateInvoicePdf(
    Map<String, dynamic> invoiceData,
  ) async {
    final pdf = pw.Document();
    final arabicFont = await _loadArabicFont();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          (80 / 25.4) * PdfPageFormat.inch,
          (210 / 25.4) * PdfPageFormat.inch,
        ),
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          // تصغير الحواف الداخلية لزيادة كثافة الطباعة على الورق بعرض 80mm
          return pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(2, 2, 2, 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        invoiceData['storeName'] ?? 'متجر الجوهر',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        invoiceData['storeAddress'] ?? 'العنوان',
                        style: pw.TextStyle(font: arabicFont),
                      ),
                      pw.Text(
                        invoiceData['storePhone'] ?? 'الهاتف',
                        style: pw.TextStyle(font: arabicFont),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),

                // Invoice info
                pw.Text(
                  'رقم الفاتورة: ${invoiceData['invoiceNumber'] ?? '#001'}',
                  style: pw.TextStyle(font: arabicFont),
                ),
                pw.Text(
                  'التاريخ: ${DateTime.now().toString().split(' ')[0]}',
                  style: pw.TextStyle(font: arabicFont),
                ),
                pw.SizedBox(height: 20),

                // Items table
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'الصنف',
                            style: pw.TextStyle(
                              font: arabicFont,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'الكمية',
                            style: pw.TextStyle(
                              font: arabicFont,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'السعر',
                            style: pw.TextStyle(
                              font: arabicFont,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'الإجمالي',
                            style: pw.TextStyle(
                              font: arabicFont,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ..._generateItemRowsPdf(invoiceData['items'] ?? []),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Totals
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'المجموع الفرعي: ${invoiceData['subtotal'] ?? '0.00'} د.ل',
                        style: pw.TextStyle(font: arabicFont),
                      ),
                      pw.Text(
                        'الضريبة: ${invoiceData['tax'] ?? '0.00'} د.ل',
                        style: pw.TextStyle(font: arabicFont),
                      ),
                      pw.Text(
                        'الإجمالي: ${invoiceData['total'] ?? '0.00'} د.ل',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),

                // Footer
                pw.Center(
                  child: pw.Text(
                    invoiceData['footerText'] ?? 'شكراً لزيارتكم',
                    style: pw.TextStyle(font: arabicFont),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  List<pw.TableRow> _generateItemRowsPdf(List<dynamic> items) {
    if (items.isEmpty) {
      return [
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('لا توجد أصناف', textAlign: pw.TextAlign.center),
            ),
            pw.Container(),
            pw.Container(),
            pw.Container(),
          ],
        ),
      ];
    }

    return items
        .map<pw.TableRow>(
          (item) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(item['name'] ?? ''),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(item['quantity']?.toString() ?? '1'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('${item['price'] ?? '0.00'} د.ل'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('${item['total'] ?? '0.00'} د.ل'),
              ),
            ],
          ),
        )
        .toList();
  }
}
