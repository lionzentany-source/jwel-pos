import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/adaptive_scaffold.dart';
import '../providers/invoice_provider.dart';
import '../providers/settings_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../models/advanced_report.dart';
import '../services/advanced_report_service.dart';

enum _ReportsMode { basic, advanced }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  Map<String, dynamic>? _salesStats;
  List<Map<String, dynamic>>? _topSellingItems;
  bool _isLoading = false;
  _ReportsMode _mode = _ReportsMode.basic;

  // Advanced report service
  final AdvancedReportService _advancedService = AdvancedReportService();

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final invoiceRepository = ref.read(invoiceRepositoryProvider);
      final salesStats = await invoiceRepository.getSalesStats(
        startDate: _startDate,
        endDate: _endDate,
      );
      final topSellingItems = await invoiceRepository.getTopSellingItems(
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _salesStats = salesStats.isNotEmpty ? salesStats.first : null;
        _topSellingItems = topSellingItems;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage('خطأ في تحميل التقارير: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);

    return AdaptiveScaffold(
      title: 'التقارير',
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showDateRangePicker,
          child: const Icon(CupertinoIcons.calendar),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: CupertinoSegmentedControl<_ReportsMode>(
              groupValue: _mode,
              onValueChanged: (m) => setState(() => _mode = m),
              children: const {
                _ReportsMode.basic: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('أساسية'),
                ),
                _ReportsMode.advanced: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text('متقدمة'),
                ),
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildDateRangeCard(),
                          const SizedBox(height: 16),
                          if (_mode == _ReportsMode.basic) ...[
                            _buildQuickReportsCard(),
                            const SizedBox(height: 16),
                            _buildSalesStatsCard(currency),
                            const SizedBox(height: 16),
                            _buildTopSellingItemsCard(currency),
                            const SizedBox(height: 16),
                            _buildActionButtons(),
                          ] else ...[
                            _buildAdvancedReportsGrid(),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'فترة التقرير',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'من: ${_formatDate(_startDate)}',
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
              Text(
                'إلى: ${_formatDate(_endDate)}',
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================== Advanced Reports Section =====================
  Widget _buildAdvancedReportsGrid() {
    final reportTypes = [
      ReportType.profitability,
      ReportType.trends,
      ReportType.comparison,
      ReportType.topCustomers,
      ReportType.cashFlow,
      ReportType.paymentMethods,
      ReportType.inventory,
      ReportType.slowMoving,
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: reportTypes.length,
      itemBuilder: (context, index) {
        final type = reportTypes[index];
        return GestureDetector(
          onTap: () => _generateAdvancedReport(type),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(type.icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                Text(
                  type.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _getReportDescription(type),
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getReportDescription(ReportType reportType) {
    switch (reportType) {
      case ReportType.profitability:
        return 'تحليل الأرباح والتكاليف';
      case ReportType.trends:
        return 'اتجاهات المبيعات الزمنية';
      case ReportType.comparison:
        return 'مقارنة بالفترة السابقة';
      case ReportType.topCustomers:
        return 'العملاء الأكثر شراءً';
      case ReportType.cashFlow:
        return 'التدفق النقدي (دخول/خروج)';
      case ReportType.paymentMethods:
        return 'تحليل طرق الدفع';
      case ReportType.inventory:
        return 'تحليل دوران المخزون';
      case ReportType.slowMoving:
        return 'الأصناف البطيئة في المخزون';
    }
  }

  Future<void> _generateAdvancedReport(ReportType type) async {
    try {
      switch (type) {
        case ReportType.profitability:
          await _showProfitabilityReport();
          break;
        case ReportType.trends:
          await _showTrendAnalysis();
          break;
        case ReportType.comparison:
          await _showComparisonReport();
          break;
        case ReportType.topCustomers:
          await _showTopCustomersReport();
          break;
        case ReportType.cashFlow:
          await _showCashFlowReport();
          break;
        case ReportType.paymentMethods:
          await _showPaymentMethodsAnalysis();
          break;
        case ReportType.inventory:
          await _showInventoryAnalysis();
          break;
        case ReportType.slowMoving:
          await _showSlowMovingReport();
          break;
      }
    } catch (e) {
      _showErrorMessage('خطأ في إنشاء التقرير: $e');
    }
  }

  Future<void> _showProfitabilityReport() async {
    final data = await _advancedService.generateProfitabilityReport(
      startDate: _startDate,
      endDate: _endDate,
    );
    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _ProfitabilityReportModal(data: data),
    );
  }

  Future<void> _showTrendAnalysis() async {
    final data = await _advancedService.generateTrendAnalysis(
      startDate: _startDate,
      endDate: _endDate,
    );
    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _TrendAnalysisModal(data: data),
    );
  }

  Future<void> _showTopCustomersReport() async {
    final data = await _advancedService.generateTopCustomersReport(
      startDate: _startDate,
      endDate: _endDate,
    );
    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _TopCustomersModal(data: data),
    );
  }

  Future<void> _showPaymentMethodsAnalysis() async {
    final data = await _advancedService.generatePaymentMethodsAnalysis(
      startDate: _startDate,
      endDate: _endDate,
    );
    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _PaymentMethodsModal(data: data),
    );
  }

  Future<void> _showInventoryAnalysis() async {
    final data = await _advancedService.generateInventoryTurnoverAnalysis();
    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _InventoryAnalysisModal(data: data),
    );
  }

  Future<void> _showComparisonReport() async {
    final data = await _advancedService.generateComparisonReport(
      startDate: _startDate,
      endDate: _endDate,
    );
    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _ComparisonReportModal(data: data),
    );
  }

  Future<void> _showCashFlowReport() async {
    final data = await _advancedService.generateCashFlowReport(
      startDate: _startDate,
      endDate: _endDate,
    );
    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _CashFlowReportModal(data: data),
    );
  }

  Future<void> _showSlowMovingReport() async {
    final data = await _advancedService.generateSlowMovingItemsReport();
    if (!mounted) return;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _SlowMovingItemsModal(data: data),
    );
  }

  Widget _buildSalesStatsCard(AsyncValue<String> currency) {
    if (_salesStats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إحصائيات المبيعات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'إجمالي الفواتير',
                  _salesStats!['totalInvoices'].toString(),
                  CupertinoColors.activeBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: currency.when(
                  data: (curr) => _buildStatCard(
                    'إجمالي المبيعات',
                    '${(_salesStats!['totalSales'] ?? 0.0).toStringAsFixed(2)} $curr',
                    CupertinoColors.activeGreen,
                  ),
                  loading: () => _buildStatCard(
                    'إجمالي المبيعات',
                    '...',
                    CupertinoColors.activeGreen,
                  ),
                  error: (_, __) => _buildStatCard(
                    'إجمالي المبيعات',
                    'خطأ',
                    CupertinoColors.activeGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: currency.when(
                  data: (curr) => _buildStatCard(
                    'متوسط البيع',
                    '${(_salesStats!['averageSale'] ?? 0.0).toStringAsFixed(2)} $curr',
                    CupertinoColors.systemOrange,
                  ),
                  loading: () => _buildStatCard(
                    'متوسط البيع',
                    '...',
                    CupertinoColors.systemOrange,
                  ),
                  error: (_, __) => _buildStatCard(
                    'متوسط البيع',
                    'خطأ',
                    CupertinoColors.systemOrange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: currency.when(
                  data: (curr) => _buildStatCard(
                    'إجمالي الخصومات',
                    '${(_salesStats!['totalDiscounts'] ?? 0.0).toStringAsFixed(2)} $curr',
                    CupertinoColors.systemRed,
                  ),
                  loading: () => _buildStatCard(
                    'إجمالي الخصومات',
                    '...',
                    CupertinoColors.systemRed,
                  ),
                  error: (_, __) => _buildStatCard(
                    'إجمالي الخصومات',
                    'خطأ',
                    CupertinoColors.systemRed,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingItemsCard(AsyncValue<String> currency) {
    if (_topSellingItems == null || _topSellingItems!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Column(
          children: [
            Text(
              'الأصناف الأكثر مبيعاً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Text(
              'لا توجد مبيعات في الفترة المحددة',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الأصناف الأكثر مبيعاً',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ..._topSellingItems!
              .take(5)
              .map((item) => _buildTopSellingItemRow(item, currency)),
        ],
      ),
    );
  }

  Widget _buildTopSellingItemRow(
    Map<String, dynamic> item,
    AsyncValue<String> currency,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['sku'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['weight_grams']}g - ${item['karat']}K',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'مبيعات: ${item['sales_count']}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.activeBlue,
                ),
              ),
              const SizedBox(height: 4),
              currency.when(
                data: (curr) => Text(
                  '${(item['total_revenue'] as double).toStringAsFixed(2)} $curr',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.activeGreen,
                  ),
                ),
                loading: () => const Text('...'),
                error: (_, __) => const Text('خطأ'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReportsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تقارير سريعة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CupertinoButton.filled(
                  onPressed: _generateWeeklyReport,
                  child: const Text('تقرير أسبوعي'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton.filled(
                  onPressed: _generateMonthlyReport,
                  child: const Text('تقرير شهري'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton.filled(
            onPressed: _exportReport,
            child: const Text('تصدير التقرير'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CupertinoButton(
            color: CupertinoColors.systemGrey,
            onPressed: _printReport,
            child: const Text('طباعة التقرير'),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDateRangePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 400,
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            Container(
              height: 50,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CupertinoColors.separator),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('إلغاء'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'اختيار الفترة',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  CupertinoButton(
                    child: const Text('تطبيق'),
                    onPressed: () {
                      Navigator.pop(context);
                      _loadReports();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Text('من تاريخ:'),
                  SizedBox(
                    height: 150,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: _startDate,
                      onDateTimeChanged: (date) {
                        _startDate = date;
                      },
                    ),
                  ),
                  const Text('إلى تاريخ:'),
                  SizedBox(
                    height: 150,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: _endDate,
                      onDateTimeChanged: (date) {
                        _endDate = date;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportReport() async {
    try {
      final htmlContent = await _generateReportHTML();
      final tempDir = await getTemporaryDirectory();
      final htmlFile = File(
        '${tempDir.path}/sales_report_${_formatDate(_startDate)}_${_formatDate(_endDate)}.html',
      );
      await htmlFile.writeAsString(htmlContent);

      final uri = Uri.file(htmlFile.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _showSuccessMessage('تم فتح التقرير في المتصفح');
      } else {
        throw Exception('Could not launch browser');
      }
    } catch (error) {
      _showErrorMessage('خطأ في تصدير التقرير: $error');
    }
  }

  Future<void> _printReport() async {
    try {
      final htmlContent = await _generateReportHTML();
      final tempDir = await getTemporaryDirectory();
      final htmlFile = File(
        '${tempDir.path}/sales_report_print_${DateTime.now().millisecondsSinceEpoch}.html',
      );
      await htmlFile.writeAsString(htmlContent);

      final uri = Uri.file(htmlFile.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _showSuccessMessage('تم فتح التقرير للطباعة');
      } else {
        throw Exception('Could not launch browser');
      }
    } catch (error) {
      _showErrorMessage('خطأ في طباعة التقرير: $error');
    }
  }

  Future<String> _generateReportHTML() async {
    final currency = await ref.read(currencyProvider.future);
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>تقرير المبيعات</title>
    <style>
        body {
            font-family: 'Arial', sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .report-container {
            max-width: 1000px;
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
        .report-title {
            font-size: 24px;
            color: #333;
            margin-bottom: 10px;
        }
        .date-range {
            font-size: 16px;
            color: #666;
            margin-bottom: 10px;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            border: 2px solid;
        }
        .stat-value {
            font-size: 24px;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .stat-label {
            font-size: 14px;
            color: #666;
        }
        .blue { border-color: #2196F3; background-color: rgba(33, 150, 243, 0.1); color: #2196F3; }
        .green { border-color: #4CAF50; background-color: rgba(76, 175, 80, 0.1); color: #4CAF50; }
        .orange { border-color: #FF9800; background-color: rgba(255, 152, 0, 0.1); color: #FF9800; }
        .red { border-color: #F44336; background-color: rgba(244, 67, 54, 0.1); color: #F44336; }
        .top-items {
            margin-top: 30px;
        }
        .section-title {
            font-size: 20px;
            font-weight: bold;
            margin-bottom: 15px;
            color: #333;
        }
        .items-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
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
        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
        }
        @media print {
            body { background-color: white; }
            .report-container { box-shadow: none; }
        }
    </style>
</head>
<body>
    <div class="report-container">
        <div class="header">
            <div class="store-name">مجوهرات جوهر</div>
            <div class="report-title">تقرير المبيعات</div>
            <div class="date-range">من ${_formatDate(_startDate)} إلى ${_formatDate(_endDate)}</div>
            <div style="font-size: 14px; color: #999;">تاريخ الطباعة: ${_formatDate(DateTime.now())}</div>
        </div>
    ''');

    if (_salesStats != null) {
      buffer.writeln('''
        <div class="stats-grid">
            <div class="stat-card blue">
                <div class="stat-value">${_salesStats!['totalInvoices']}</div>
                <div class="stat-label">إجمالي الفواتير</div>
            </div>
            <div class="stat-card green">
                <div class="stat-value">${(_salesStats!['totalSales'] ?? 0.0).toStringAsFixed(2)} $currency</div>
                <div class="stat-label">إجمالي المبيعات</div>
            </div>
            <div class="stat-card orange">
                <div class="stat-value">${(_salesStats!['averageSale'] ?? 0.0).toStringAsFixed(2)} $currency</div>
                <div class="stat-label">متوسط البيع</div>
            </div>
            <div class="stat-card red">
                <div class="stat-value">${(_salesStats!['totalDiscounts'] ?? 0.0).toStringAsFixed(2)} $currency</div>
                <div class="stat-label">إجمالي الخصومات</div>
            </div>
        </div>
      ''');
    }

    if (_topSellingItems != null && _topSellingItems!.isNotEmpty) {
      buffer.writeln('''
        <div class="top-items">
            <div class="section-title">الأصناف الأكثر مبيعاً</div>
            <table class="items-table">
                <thead>
                    <tr>
                        <th>الصنف</th>
                        <th>الوزن</th>
                        <th>العيار</th>
                        <th>عدد المبيعات</th>
                        <th>إجمالي الإيرادات</th>
                    </tr>
                </thead>
                <tbody>
      ''');

      for (final item in _topSellingItems!.take(10)) {
        buffer.writeln('''
                    <tr>
                        <td>${item['sku']}</td>
                        <td>${item['weight_grams']}g</td>
                        <td>${item['karat']}K</td>
                        <td>${item['sales_count']}</td>
                        <td>${(item['total_revenue'] as double).toStringAsFixed(2)} $currency</td>
                    </tr>
        ''');
      }

      buffer.writeln('''
                </tbody>
            </table>
        </div>
      ''');
    }

    buffer.writeln('''
        <div class="footer">
            <p>تقرير من نظام جوهر</p>
            <p>مجوهرات جوهر - جودة وثقة</p>
        </div>
    </div>
    
    <script>
        // Auto-print when page loads for print function
        if (window.location.href.includes('print')) {
            window.onload = function() {
                setTimeout(function() {
                    window.print();
                }, 1000);
            };
        }
    </script>
</body>
</html>
    ''');

    return buffer.toString();
  }

  void _showSuccessMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('تم بنجاح'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('خطأ'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('موافق'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _generateWeeklyReport() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    setState(() {
      _startDate = startOfWeek;
      _endDate = endOfWeek;
    });

    await _loadReports();
    _showReportOptions('تقرير أسبوعي');
  }

  Future<void> _generateMonthlyReport() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    setState(() {
      _startDate = startOfMonth;
      _endDate = endOfMonth;
    });

    await _loadReports();
    _showReportOptions('تقرير شهري');
  }

  void _showReportOptions(String reportType) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(reportType),
        message: const Text('اختر الإجراء المطلوب'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('عرض التقرير'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('طباعة التقرير'),
            onPressed: () {
              Navigator.pop(context);
              _printReport();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('تصدير التقرير'),
            onPressed: () {
              Navigator.pop(context);
              _exportReport();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('إلغاء'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

// ===================== Advanced Report Modal Widgets =====================
class _ProfitabilityReportModal extends StatelessWidget {
  final ProfitabilityData data;
  const _ProfitabilityReportModal({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CupertinoColors.separator),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('إغلاق'),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'تقرير الربحية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 60),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _profitCard(
                    'إجمالي الإيرادات',
                    data.totalRevenue,
                    CupertinoColors.activeGreen,
                  ),
                  const SizedBox(height: 12),
                  _profitCard(
                    'إجمالي التكاليف',
                    data.totalCost,
                    CupertinoColors.systemRed,
                  ),
                  const SizedBox(height: 12),
                  _profitCard(
                    'صافي الربح',
                    data.grossProfit,
                    CupertinoColors.activeBlue,
                  ),
                  const SizedBox(height: 12),
                  _profitCard(
                    'هامش الربح',
                    data.profitMargin,
                    CupertinoColors.systemOrange,
                    isPercentage: true,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'الربحية حسب الفئة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...data.categoryProfits.map(_categoryProfitRow),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profitCard(
    String label,
    double value,
    Color color, {
    bool isPercentage = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            isPercentage
                ? '${value.toStringAsFixed(1)}%'
                : '${value.toStringAsFixed(2)} د.ل',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryProfitRow(CategoryProfit cp) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cp.categoryName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الإيرادات: ${cp.revenue.toStringAsFixed(2)} د.ل'),
              Text('الربح: ${cp.profit.toStringAsFixed(2)} د.ل'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('التكلفة: ${cp.cost.toStringAsFixed(2)} د.ل'),
              Text('الهامش: ${cp.margin.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendAnalysisModal extends StatelessWidget {
  final TrendData data;
  const _TrendAnalysisModal({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CupertinoColors.separator),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('إغلاق'),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'تحليل الاتجاهات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 60),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _trendSummary(),
                  const SizedBox(height: 20),
                  const Text(
                    'المبيعات الشهرية',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...data.monthlySales.map(_monthlySalesRow),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الاتجاه العام:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                data.trend,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: data.trend == 'متزايد'
                      ? CupertinoColors.activeGreen
                      : data.trend == 'متناقص'
                      ? CupertinoColors.systemRed
                      : CupertinoColors.systemOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'معدل النمو:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${data.growthRate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: data.growthRate > 0
                      ? CupertinoColors.activeGreen
                      : data.growthRate < 0
                      ? CupertinoColors.systemRed
                      : CupertinoColors.systemOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthlySalesRow(MonthlySales ms) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${ms.month}/${ms.year}'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${ms.sales.toStringAsFixed(2)} د.ل'),
              Text(
                '${ms.invoiceCount} فاتورة',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopCustomersModal extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _TopCustomersModal({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CupertinoColors.separator),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('إغلاق'),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'أفضل العملاء',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 60),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              itemBuilder: (context, i) => _customerRow(data[i], i + 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerRow(Map<String, dynamic> c, int rank) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['customerName'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (c['customerPhone'].isNotEmpty)
                  Text(
                    c['customerPhone'],
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${c['totalSpent'].toStringAsFixed(2)} د.ل',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.activeGreen,
                ),
              ),
              Text(
                '${c['invoiceCount']} فاتورة',
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodsModal extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PaymentMethodsModal({required this.data});

  @override
  Widget build(BuildContext context) {
    final amounts = data['amounts'] as Map<String, double>;
    final percentages = data['percentages'] as Map<String, double>;
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CupertinoColors.separator),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('إغلاق'),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'تحليل طرق الدفع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 60),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: amounts.entries
                  .map(
                    (e) => _paymentRow(e.key, e.value, percentages[e.key] ?? 0),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentRow(String method, double amount, double percentage) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(method, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${amount.toStringAsFixed(2)} د.ل',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${percentage.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryAnalysisModal extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InventoryAnalysisModal({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CupertinoColors.separator),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('إغلاق'),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  'تحليل المخزون',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 60),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _inventorySummary(),
                  const SizedBox(height: 20),
                  const Text(
                    'تحليل الفئات',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ..._categoryAnalysis(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inventorySummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إجمالي الأصناف:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${data['totalItems']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'المباع:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${data['soldItems']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'في المخزون:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${data['inStockItems']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'معدل الدوران:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${(data['turnoverRate'] * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _categoryAnalysis() {
    final categoryAnalysis =
        data['categoryAnalysis'] as Map<String, Map<String, dynamic>>;
    return categoryAnalysis.entries.map((e) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الإجمالي: ${e.value['total']}'),
                Text('المباع: ${e.value['sold']}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('في المخزون: ${e.value['inStock']}'),
                Text('القيمة: ${e.value['value'].toStringAsFixed(2)} د.ل'),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }
}

// ========== New Modals: Comparison, Cash Flow, Slow Moving =============
class _ComparisonReportModal extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ComparisonReportModal({required this.data});

  @override
  Widget build(BuildContext context) {
    final period = data['period'] as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>;
    final previous = data['previous'] as Map<String, dynamic>;
    final growth = data['growth'] as Map<String, dynamic>;

    String _fmtPct(double v) => '${v.toStringAsFixed(1)}%';
    Widget diffRow(String label, double curr, double prev, double pct) {
      final color = pct > 0
          ? CupertinoColors.activeGreen
          : pct < 0
          ? CupertinoColors.systemRed
          : CupertinoColors.secondaryLabel;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CupertinoColors.separator)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                prev.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(curr.toStringAsFixed(2), textAlign: TextAlign.center),
            ),
            SizedBox(
              width: 70,
              child: Text(
                _fmtPct(pct),
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _modalHeader(context, 'مقارنة الأداء'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الفترة الحالية: ${period['currentStart'].toString().split(' ').first} → ${period['currentEnd'].toString().split(' ').first}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'الفترة السابقة: ${period['previousStart'].toString().split(' ').first} → ${period['previousEnd'].toString().split(' ').first}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            Expanded(child: SizedBox()),
                            SizedBox(
                              width: 90,
                              child: Text(
                                'سابق',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                'حالي',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                'النمو',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        diffRow(
                          'المبيعات',
                          current['totalSales'],
                          previous['totalSales'],
                          growth['salesGrowth'],
                        ),
                        diffRow(
                          'عدد الفواتير',
                          current['invoiceCount'].toDouble(),
                          previous['invoiceCount'].toDouble(),
                          growth['invoiceGrowth'],
                        ),
                        diffRow(
                          'متوسط الفاتورة',
                          current['averageSale'],
                          previous['averageSale'],
                          growth['averageGrowth'],
                        ),
                        diffRow(
                          'الخصومات',
                          current['discounts'],
                          previous['discounts'],
                          growth['discountChange'],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowReportModal extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CashFlowReportModal({required this.data});
  @override
  Widget build(BuildContext context) {
    final byMethod = (data['byMethod'] as Map<String, double>);
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _modalHeader(context, 'التدفق النقدي'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cashRow('التدفقات الداخلة (مبيعات)', data['cashIn'], CupertinoColors.activeGreen),
                  const SizedBox(height: 8),
                  _cashRow('تكلفة البضاعة (خروج)', data['inventoryCost'], CupertinoColors.systemRed),
                  const SizedBox(height: 8),
                  _cashRow('مصروفات تشغيلية', data['operatingExpenses'], CupertinoColors.systemOrange),
                  const SizedBox(height: 8),
                  _cashRow('إجمالي التدفقات الخارجة', data['cashOut'], CupertinoColors.destructiveRed),
                  const SizedBox(height: 8),
                  _cashRow('صافي التدفق', data['netCash'], CupertinoColors.activeBlue),
                  const SizedBox(height: 20),
                  const Text(
                    'حسب طريقة الدفع',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...byMethod.entries.map(
                    (e) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key),
                          Text(
                            '${e.value.toStringAsFixed(2)} د.ل',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cashRow(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            '${value.toStringAsFixed(2)} د.ل',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _SlowMovingItemsModal extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SlowMovingItemsModal({required this.data});
  @override
  Widget build(BuildContext context) {
    final items = data['items'] as List<dynamic>;
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _modalHeader(context, 'الأصناف البطيئة'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عتبة الأيام: ${data['thresholdDays']}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'النسبة: ${data['slowPercentage'].toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text('لا توجد أصناف بطيئة حسب العتبة الحالية'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (c, i) {
                      final it = items[i] as Map<String, dynamic>;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it['sku'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${it['weight']}g - ${it['karat']}K',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: CupertinoColors.secondaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${it['ageDays']} يوم',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: CupertinoColors.systemOrange,
                                  ),
                                ),
                                Text(
                                  (it['createdAt'] as DateTime)
                                      .toString()
                                      .split(' ')
                                      .first,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: items.length,
                  ),
          ),
        ],
      ),
    );
  }
}

// Shared small header
Widget _modalHeader(BuildContext context, String title) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: CupertinoColors.separator)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 60),
      ],
    ),
  );
}
