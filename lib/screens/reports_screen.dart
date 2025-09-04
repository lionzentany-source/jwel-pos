import 'package:flutter/cupertino.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/adaptive_scaffold.dart';
import '../widgets/app_button.dart';
import '../providers/invoice_provider.dart';
import '../providers/item_provider.dart';
import '../providers/settings_provider.dart';
import '../models/item.dart';
import '../models/advanced_report.dart';
import '../services/advanced_report_service.dart';
import '../services/report_service.dart';
import '../widgets/side_sheet.dart';
import '../services/report_filters_storage.dart';
import '../providers/category_provider.dart';
import '../models/invoice.dart';

// Consolidated single-page reports (basic + advanced)

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
  ItemLocation? _inventoryLocationFilter;
  bool _groupInventoryByLocation = false;
  int? _categoryId;
  PaymentMethod? _paymentMethod;
  // Lightweight data for charts
  Map<String, double>? _paymentDistribution;
  TrendData? _trendData;

  // Advanced report service
  final AdvancedReportService _advancedService = AdvancedReportService();

  @override
  void initState() {
    super.initState();
    _restoreFiltersAndLoad();
  }

  Future<void> _restoreFiltersAndLoad() async {
    try {
      final saved = await ReportFiltersStorage.load();
      setState(() {
        _startDate = saved.startDate ?? _startDate;
        _endDate = saved.endDate ?? _endDate;
        _inventoryLocationFilter = saved.inventoryLocation;
        _groupInventoryByLocation = saved.groupByLocation;
        _categoryId = saved.categoryId;
        _paymentMethod = saved.paymentMethod;
      });
    } catch (_) {}
    await _loadReports();
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
        categoryId: _categoryId,
        paymentMethod: _paymentMethod,
        itemLocation: _inventoryLocationFilter,
      );
      final topSellingItems = await invoiceRepository.getTopSellingItems(
        startDate: _startDate,
        endDate: _endDate,
        categoryId: _categoryId,
        paymentMethod: _paymentMethod,
        itemLocation: _inventoryLocationFilter,
      );
      // Charts data
      final payments = await _advancedService.generatePaymentMethodsAnalysis(
        startDate: _startDate,
        endDate: _endDate,
        categoryId: _categoryId,
        paymentMethod: _paymentMethod,
        itemLocation: _inventoryLocationFilter,
      );
      final trend = await _advancedService.generateTrendAnalysis(
        startDate: _startDate,
        endDate: _endDate,
        categoryId: _categoryId,
        paymentMethod: _paymentMethod,
        itemLocation: _inventoryLocationFilter,
      );

      setState(() {
        _salesStats = salesStats.isNotEmpty ? salesStats.first : null;
        _topSellingItems = topSellingItems;
        _paymentDistribution = (payments['amounts'] as Map<String, double>);
        _trendData = trend;
        _isLoading = false;
      });
      // Persist current filters
      await ReportFiltersStorage.save(
        ReportFilters(
          startDate: _startDate,
          endDate: _endDate,
          inventoryLocation: _inventoryLocationFilter,
          groupByLocation: _groupInventoryByLocation,
          categoryId: _categoryId,
          paymentMethod: _paymentMethod,
        ),
      );
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

    return Container(
      color: Color(0xfff6f8fa), // خلفية موحدة
      child: AdaptiveScaffold(
        title: 'التقارير',
        commandBarItems: [
          CommandBarButton(
            icon: const Icon(FluentIcons.calendar, size: 20),
            label: const Text(
              'اليوم',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              final now = DateTime.now();
              setState(() {
                _startDate = DateTime(now.year, now.month, now.day);
                _endDate = now;
              });
              await _loadReports();
            },
          ),
          CommandBarButton(
            icon: const Icon(FluentIcons.calendar, size: 20),
            label: const Text(
              'هذا الأسبوع',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              final now = DateTime.now();
              final start = now.subtract(Duration(days: now.weekday - 1));
              final end = start.add(const Duration(days: 6));
              setState(() {
                _startDate = DateTime(start.year, start.month, start.day);
                _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
              });
              await _loadReports();
            },
          ),
          CommandBarButton(
            icon: const Icon(FluentIcons.calendar, size: 20),
            label: const Text(
              'هذا الشهر',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              final now = DateTime.now();
              final start = DateTime(now.year, now.month, 1);
              final end = DateTime(now.year, now.month + 1, 0);
              setState(() {
                _startDate = start;
                _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
              });
              await _loadReports();
            },
          ),
          const CommandBarSeparator(),
          CommandBarButton(
            icon: const Icon(FluentIcons.filter_settings, size: 20),
            label: const Text(
              'الفلاتر',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onPressed: _openFilters,
          ),
          CommandBarButton(
            icon: const Icon(FluentIcons.calendar, size: 20),
            label: const Text(
              'تحديد الفترة',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            onPressed: _showDateRangePicker,
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _buildDateRangeCard(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: ProgressRing())
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildOverviewSection(currency),
                            const SizedBox(height: 16),
                            _buildTopSellingItemsCard(currency),
                            const SizedBox(height: 16),
                            _buildInventoryExportCard(),
                            const SizedBox(height: 16),
                            Expander(
                              header: const Text('تقارير متقدمة'),
                              content: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: _buildAdvancedReportsGrid(),
                              ),
                              initiallyExpanded: false,
                            ),
                            const SizedBox(height: 16),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Overview section with KPIs and lightweight charts
  Widget _buildOverviewSection(AsyncValue<String> currency) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            'نظرة عامة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildSalesStatsCard(currency),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [_buildPaymentDistributionPie(), _buildTrendLineChart()],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDistributionPie() {
    final data = _paymentDistribution;
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    final total = data.values.fold<double>(0.0, (p, c) => p + c);
    final sections = <PieChartSectionData>[];
    final colors = [
      CupertinoColors.activeBlue,
      CupertinoColors.activeGreen,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPurple,
      CupertinoColors.systemRed,
      CupertinoColors.systemTeal,
    ];
    int i = 0;
    data.forEach((label, value) {
      final color = colors[i % colors.length];
      sections.add(
        PieChartSectionData(
          value: value,
          color: color,
          title: total > 0
              ? '${((value / total) * 100).toStringAsFixed(0)}%'
              : '0%',
        ),
      );
      i++;
    });
    return SizedBox(
      width: 380,
      height: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'توزيع طرق الدفع',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.entries.map((e) {
                    final idx = data.keys.toList().indexOf(e.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            color: colors[idx % colors.length],
                          ),
                          const SizedBox(width: 6),
                          Text('${e.key}: ${e.value.toStringAsFixed(2)}'),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendLineChart() {
    final t = _trendData;
    if (t == null || t.monthlySales.isEmpty) return const SizedBox.shrink();
    final spots = <FlSpot>[];
    for (var i = 0; i < t.monthlySales.length; i++) {
      spots.add(FlSpot(i.toDouble(), t.monthlySales[i].sales));
    }
    return SizedBox(
      width: 380,
      height: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اتجاه المبيعات',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= t.monthlySales.length) {
                          return const SizedBox.shrink();
                        }
                        final m = t.monthlySales[idx];
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '${m.month}/${m.year % 100}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    barWidth: 3,
                    color: CupertinoColors.activeGreen,
                    spots: spots,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFilters() {
    showSideSheet(
      context,
      title: 'الفلاتر',
      width: 420,
      child: Consumer(
        builder: (context, ref, _) {
          final categories = ref.watch(categoriesProvider);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الفترة',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await _pickDate(true);
                        },
                        child: Text(
                          'من: ${_formatDate(_startDate)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await _pickDate(false);
                        },
                        child: Text(
                          'إلى: ${_formatDate(_endDate)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'مكان التقرير',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ComboBox<ItemLocation?>(
                  isExpanded: true,
                  value: _inventoryLocationFilter,
                  items: [
                    const ComboBoxItem<ItemLocation?>(
                      value: null,
                      child: Text('كل الأماكن'),
                    ),
                    ...ItemLocation.values.map(
                      (loc) => ComboBoxItem<ItemLocation?>(
                        value: loc,
                        child: Text(loc.displayName),
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _inventoryLocationFilter = v),
                ),
                const SizedBox(height: 8),
                ToggleSwitch(
                  checked: _groupInventoryByLocation,
                  onChanged: (v) =>
                      setState(() => _groupInventoryByLocation = v),
                  content: const Text('تجميع حسب المكان'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'الفئة',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                categories.when(
                  data: (list) => ComboBox<int?>(
                    isExpanded: true,
                    value: _categoryId,
                    items: [
                      const ComboBoxItem<int?>(
                        value: null,
                        child: Text('كل الفئات'),
                      ),
                      ...list.map(
                        (c) => ComboBoxItem<int?>(
                          value: c.id,
                          child: Text(c.nameAr),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                  loading: () => const ProgressBar(),
                  error: (_, __) => const Text('تعذر تحميل الفئات'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'طريقة الدفع',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ComboBox<PaymentMethod?>(
                  isExpanded: true,
                  value: _paymentMethod,
                  items: [
                    const ComboBoxItem<PaymentMethod?>(
                      value: null,
                      child: Text('كل الطرق'),
                    ),
                    ...PaymentMethod.values.map(
                      (m) => ComboBoxItem<PaymentMethod?>(
                        value: m,
                        child: Text(m.displayName),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _paymentMethod = v),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Button(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('إغلاق'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.of(context).maybePop();
                          await ReportFiltersStorage.save(
                            ReportFilters(
                              startDate: _startDate,
                              endDate: _endDate,
                              inventoryLocation: _inventoryLocationFilter,
                              groupByLocation: _groupInventoryByLocation,
                              categoryId: _categoryId,
                              paymentMethod: _paymentMethod,
                            ),
                          );
                          await _loadReports();
                        },
                        child: const Text('تطبيق'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    DateTime temp = isStart ? _startDate : _endDate;
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
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
                    'اختر التاريخ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  CupertinoButton(
                    child: const Text('تم'),
                    onPressed: () {
                      setState(() {
                        if (isStart) {
                          _startDate = temp;
                        } else {
                          _endDate = temp;
                        }
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: temp,
                onDateTimeChanged: (d) => temp = d,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryExportCard() {
    String locLabel;
    if (_inventoryLocationFilter == null) {
      locLabel = 'كل الأماكن';
    } else {
      locLabel = _inventoryLocationFilter!.displayName;
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
            'تقرير المخزون',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  color: CupertinoColors.systemGrey6,
                  onPressed: _pickInventoryLocation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('مكان التقرير: $locLabel'),
                      const Icon(CupertinoIcons.chevron_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ToggleSwitch(
                checked: _groupInventoryByLocation,
                onChanged: (v) => setState(() => _groupInventoryByLocation = v),
                content: const Text('تجميع حسب المكان'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton.primary(
                  text: 'PDF تصدير',
                  onPressed: _exportInventoryPdf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.secondary(
                  text: 'Excel تصدير',
                  onPressed: _exportInventoryExcel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _pickInventoryLocation() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('اختر مكان التقرير'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('كل الأماكن'),
            onPressed: () {
              setState(() => _inventoryLocationFilter = null);
              Navigator.pop(context);
            },
          ),
          ...ItemLocation.values.map(
            (loc) => CupertinoActionSheetAction(
              child: Text(loc.displayName),
              onPressed: () {
                setState(() => _inventoryLocationFilter = loc);
                Navigator.pop(context);
              },
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('إلغاء'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _exportInventoryPdf() async {
    try {
      final repo = ref.read(itemRepositoryProvider);
      final items = await repo.getAllItems(location: _inventoryLocationFilter);
      if (items.isEmpty) {
        _showErrorMessage('لا توجد أصناف للتصدير وفق المكان المختار');
        return;
      }
      final path = await ReportService().exportInventoryReportToPDF(
        items: items,
        filterLocation: _inventoryLocationFilter,
        groupByLocation: _groupInventoryByLocation,
      );
      final uri = Uri.file(path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _showSuccessMessage('تم إنشاء التقرير وفتحه');
      } else {
        _showSuccessMessage('تم إنشاء التقرير: $path');
      }
    } catch (e) {
      _showErrorMessage('فشل تصدير تقرير المخزون: $e');
    }
  }

  Future<void> _exportInventoryExcel() async {
    try {
      final repo = ref.read(itemRepositoryProvider);
      final items = await repo.getAllItems(location: _inventoryLocationFilter);
      if (items.isEmpty) {
        _showErrorMessage('لا توجد أصناف للتصدير وفق المكان المختار');
        return;
      }
      final filePath = await ReportService().exportToExcel(
        reportType: 'Inventory Report',
        data: items,
      );
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _showSuccessMessage('تم إنشاء ملف Excel وفتحه');
      } else {
        _showSuccessMessage('تم إنشاء ملف Excel: $filePath');
      }
    } catch (e) {
      _showErrorMessage('فشل تصدير Excel للمخزون: $e');
    }
  }

  Widget _buildDateRangeCard() {
    return Card(
      padding: const EdgeInsets.all(16),
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
          child: Card(
            padding: const EdgeInsets.all(16),
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
      categoryId: _categoryId,
      paymentMethod: _paymentMethod,
      itemLocation: _inventoryLocationFilter,
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
      categoryId: _categoryId,
      paymentMethod: _paymentMethod,
      itemLocation: _inventoryLocationFilter,
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
      categoryId: _categoryId,
      paymentMethod: _paymentMethod,
      itemLocation: _inventoryLocationFilter,
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
      categoryId: _categoryId,
      paymentMethod: _paymentMethod,
      itemLocation: _inventoryLocationFilter,
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
      categoryId: _categoryId,
      paymentMethod: _paymentMethod,
      itemLocation: _inventoryLocationFilter,
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
      categoryId: _categoryId,
      paymentMethod: _paymentMethod,
      itemLocation: _inventoryLocationFilter,
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

  // Removed old quick reports card (replaced by command bar quick filters)

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: AppButton.primary(
            text: 'تصدير PDF',
            onPressed: _exportSalesPdf,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  text: 'Excel',
                  onPressed: _exportSalesExcel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton.secondary(
                  text: 'CSV',
                  onPressed: _exportSalesCsv,
                ),
              ),
            ],
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
              child: SingleChildScrollView(
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSalesPdf() async {
    try {
      final invoiceRepo = ref.read(invoiceRepositoryProvider);
      final invoices = await invoiceRepo.getInvoicesByDateRange(
        startDate: _startDate,
        endDate: _endDate,
        categoryId: _categoryId,
        paymentMethod: _paymentMethod,
        itemLocation: _inventoryLocationFilter,
      );
      if (invoices.isEmpty) {
        _showErrorMessage('لا توجد فواتير في الفترة/الفلاتر المحددة');
        return;
      }
      final path = await ReportService().exportSalesReportToPDF(
        invoices: invoices,
        startDate: _startDate,
        endDate: _endDate,
      );
      final uri = Uri.file(path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      _showSuccessMessage('تم إنشاء تقرير PDF');
    } catch (e) {
      _showErrorMessage('فشل تصدير PDF: $e');
    }
  }

  Future<void> _exportSalesExcel() async {
    try {
      final invoiceRepo = ref.read(invoiceRepositoryProvider);
      final invoices = await invoiceRepo.getInvoicesByDateRange(
        startDate: _startDate,
        endDate: _endDate,
        categoryId: _categoryId,
        paymentMethod: _paymentMethod,
        itemLocation: _inventoryLocationFilter,
      );
      if (invoices.isEmpty) {
        _showErrorMessage('لا توجد فواتير في الفترة/الفلاتر المحددة');
        return;
      }
      final filePath = await ReportService().exportToExcel(
        reportType: 'Sales Report',
        data: invoices,
      );
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      _showSuccessMessage('تم إنشاء ملف Excel');
    } catch (e) {
      _showErrorMessage('فشل تصدير Excel: $e');
    }
  }

  Future<void> _exportSalesCsv() async {
    try {
      final invoiceRepo = ref.read(invoiceRepositoryProvider);
      final invoices = await invoiceRepo.getInvoicesByDateRange(
        startDate: _startDate,
        endDate: _endDate,
        categoryId: _categoryId,
        paymentMethod: _paymentMethod,
        itemLocation: _inventoryLocationFilter,
      );
      if (invoices.isEmpty) {
        _showErrorMessage('لا توجد فواتير في الفترة/الفلاتر المحددة');
        return;
      }
      final path = await ReportService().exportSalesReportToCSV(
        invoices: invoices,
        startDate: _startDate,
        endDate: _endDate,
      );
      final uri = Uri.file(path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      _showSuccessMessage('تم إنشاء ملف CSV');
    } catch (e) {
      _showErrorMessage('فشل تصدير CSV: $e');
    }
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

  // Removed legacy quick report generators (replaced by command bar shortcuts)
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
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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

    double asDoubleSafe(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    String formatPercent(double v) => '${v.toStringAsFixed(1)}%';
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
                formatPercent(pct),
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
                          asDoubleSafe(current['totalSales']),
                          asDoubleSafe(previous['totalSales']),
                          asDoubleSafe(growth['salesGrowth']),
                        ),
                        diffRow(
                          'عدد الفواتير',
                          asDoubleSafe(current['invoiceCount']),
                          asDoubleSafe(previous['invoiceCount']),
                          asDoubleSafe(growth['invoiceGrowth']),
                        ),
                        diffRow(
                          'متوسط الفاتورة',
                          asDoubleSafe(current['averageSale']),
                          asDoubleSafe(previous['averageSale']),
                          asDoubleSafe(growth['averageGrowth']),
                        ),
                        diffRow(
                          'الخصومات',
                          asDoubleSafe(current['discounts']),
                          asDoubleSafe(previous['discounts']),
                          asDoubleSafe(growth['discountChange']),
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
                  _cashRow(
                    'التدفقات الداخلة (مبيعات)',
                    data['cashIn'],
                    CupertinoColors.activeGreen,
                  ),
                  const SizedBox(height: 8),
                  _cashRow(
                    'تكلفة البضاعة (خروج)',
                    data['inventoryCost'],
                    CupertinoColors.systemRed,
                  ),
                  const SizedBox(height: 8),
                  _cashRow(
                    'مصروفات تشغيلية',
                    data['operatingExpenses'],
                    CupertinoColors.systemOrange,
                  ),
                  const SizedBox(height: 8),
                  _cashRow(
                    'إجمالي التدفقات الخارجة',
                    data['cashOut'],
                    CupertinoColors.destructiveRed,
                  ),
                  const SizedBox(height: 8),
                  _cashRow(
                    'صافي التدفق',
                    data['netCash'],
                    CupertinoColors.activeBlue,
                  ),
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
        SizedBox(
          width: 100,
          child: AppButton.secondary(
            text: 'إغلاق',
            onPressed: () => Navigator.pop(context),
          ),
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
