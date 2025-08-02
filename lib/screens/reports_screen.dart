import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/adaptive_scaffold.dart';
import '../repositories/invoice_repository.dart';
import '../providers/settings_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  Map<String, dynamic>? _salesStats;
  List<Map<String, dynamic>>? _topSellingItems;
  bool _isLoading = false;

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
      final salesStats = await _invoiceRepository.getSalesStats(
        _startDate,
        _endDate,
      );
      final topSellingItems = await _invoiceRepository.getTopSellingItems(
        _startDate,
        _endDate,
      );

      setState(() {
        _salesStats = salesStats;
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
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // فترة التقرير
                  _buildDateRangeCard(),

                  const SizedBox(height: 16),

                  // إحصائيات المبيعات
                  _buildSalesStatsCard(currency),

                  const SizedBox(height: 16),

                  // الأصناف الأكثر مبيعاً
                  _buildTopSellingItemsCard(currency),

                  const SizedBox(height: 16),

                  // أزرار إضافية
                  _buildActionButtons(),
                ],
              ),
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
                    '${(_salesStats!['totalSales'] as double).toStringAsFixed(2)} $curr',
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
                    '${(_salesStats!['averageSale'] as double).toStringAsFixed(2)} $curr',
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
                    '${(_salesStats!['totalDiscounts'] as double).toStringAsFixed(2)} $curr',
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

  void _exportReport() {
    // سيتم إضافة تصدير التقارير في التحديث القادم
    _showSuccessMessage('سيتم إضافة ميزة التصدير في التحديث القادم');
  }

  void _printReport() {
    // سيتم إضافة طباعة التقارير في التحديث القادم
    _showSuccessMessage('سيتم إضافة ميزة الطباعة في التحديث القادم');
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
}
