import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/adaptive_scaffold.dart';
import '../models/advanced_report.dart';
import '../services/advanced_report_service.dart';

class AdvancedReportsScreen extends ConsumerStatefulWidget {
  const AdvancedReportsScreen({super.key});

  @override
  ConsumerState<AdvancedReportsScreen> createState() =>
      _AdvancedReportsScreenState();
}

class _AdvancedReportsScreenState extends ConsumerState<AdvancedReportsScreen> {
  final AdvancedReportService _reportService = AdvancedReportService();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xfff6f8fa), // خلفية موحدة
      child: AdaptiveScaffold(
        title: 'التقارير المتقدمة',
        actions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showDateRangePicker,
            child: const Icon(
              CupertinoIcons.calendar,
              color: Color(0xff0078D4),
            ),
          ),
        ],
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDateRangeCard(),
              const SizedBox(height: 16),
              _buildReportCategoriesGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeCard() {
    return AdaptiveCard(
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

  Widget _buildReportCategoriesGrid() {
    final reportTypes = [
      ReportType.profitability,
      ReportType.trends,
      ReportType.topCustomers,
      ReportType.paymentMethods,
      ReportType.inventory,
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: reportTypes.length,
      itemBuilder: (context, index) {
        final reportType = reportTypes[index];
        return _buildReportCard(reportType);
      },
    );
  }

  Widget _buildReportCard(ReportType reportType) {
    return GestureDetector(
      onTap: () => _generateReport(reportType),
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
            Text(reportType.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(
              reportType.displayName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getReportDescription(reportType),
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
  }

  String _getReportDescription(ReportType reportType) {
    switch (reportType) {
      case ReportType.profitability:
        return 'تحليل الأرباح والتكاليف';
      case ReportType.trends:
        return 'اتجاهات المبيعات الزمنية';
      case ReportType.topCustomers:
        return 'العملاء الأكثر شراءً';
      case ReportType.paymentMethods:
        return 'تحليل طرق الدفع';
      case ReportType.inventory:
        return 'تحليل دوران المخزون';
      default:
        return '';
    }
  }

  Future<void> _generateReport(ReportType reportType) async {
    try {
      switch (reportType) {
        case ReportType.profitability:
          await _showProfitabilityReport();
          break;
        case ReportType.trends:
          await _showTrendAnalysis();
          break;
        case ReportType.topCustomers:
          await _showTopCustomersReport();
          break;
        case ReportType.paymentMethods:
          await _showPaymentMethodsAnalysis();
          break;
        case ReportType.inventory:
          await _showInventoryAnalysis();
          break;
        default:
          _showErrorMessage('نوع التقرير غير مدعوم');
      }
    } catch (e) {
      _showErrorMessage('خطأ في إنشاء التقرير: $e');
    }
  }

  Future<void> _showProfitabilityReport() async {
    final data = await _reportService.generateProfitabilityReport(
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
    final data = await _reportService.generateTrendAnalysis(
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
    final data = await _reportService.generateTopCustomersReport(
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
    final data = await _reportService.generatePaymentMethodsAnalysis(
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
    final data = await _reportService.generateInventoryTurnoverAnalysis();

    if (!mounted) return;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => _InventoryAnalysisModal(data: data),
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
                      setState(() {});
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
}

// Modal widgets for different report types
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
                  _buildProfitCard(
                    'إجمالي الإيرادات',
                    data.totalRevenue,
                    CupertinoColors.activeGreen,
                  ),
                  const SizedBox(height: 12),
                  _buildProfitCard(
                    'إجمالي التكاليف',
                    data.totalCost,
                    CupertinoColors.systemRed,
                  ),
                  const SizedBox(height: 12),
                  _buildProfitCard(
                    'صافي الربح',
                    data.grossProfit,
                    CupertinoColors.activeBlue,
                  ),
                  const SizedBox(height: 12),
                  _buildProfitCard(
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
                  ...data.categoryProfits.map(
                    (cp) => _buildCategoryProfitRow(cp),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitCard(
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

  Widget _buildCategoryProfitRow(CategoryProfit cp) {
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
                  _buildTrendSummary(),
                  const SizedBox(height: 20),
                  const Text(
                    'المبيعات الشهرية',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...data.monthlySales.map((ms) => _buildMonthlySalesRow(ms)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendSummary() {
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

  Widget _buildMonthlySalesRow(MonthlySales ms) {
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
              itemBuilder: (context, index) {
                final customer = data[index];
                return _buildCustomerRow(customer, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(Map<String, dynamic> customer, int rank) {
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
                  customer['customerName'],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (customer['customerPhone'].isNotEmpty)
                  Text(
                    customer['customerPhone'],
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
                '${customer['totalSpent'].toStringAsFixed(2)} د.ل',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.activeGreen,
                ),
              ),
              Text(
                '${customer['invoiceCount']} فاتورة',
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
              children: amounts.entries.map((entry) {
                return _buildPaymentMethodRow(
                  entry.key,
                  entry.value,
                  percentages[entry.key] ?? 0,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(
    String method,
    double amount,
    double percentage,
  ) {
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
                  _buildInventorySummary(),
                  const SizedBox(height: 20),
                  const Text(
                    'تحليل الفئات',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ..._buildCategoryAnalysis(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySummary() {
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

  List<Widget> _buildCategoryAnalysis() {
    final categoryAnalysis =
        data['categoryAnalysis'] as Map<String, Map<String, dynamic>>;

    return categoryAnalysis.entries.map((entry) {
      final categoryName = entry.key;
      final categoryData = entry.value;

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
              categoryName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الإجمالي: ${categoryData['total']}'),
                Text('المباع: ${categoryData['sold']}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('في المخزون: ${categoryData['inStock']}'),
                Text('القيمة: ${categoryData['value'].toStringAsFixed(2)} د.ل'),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }
}
