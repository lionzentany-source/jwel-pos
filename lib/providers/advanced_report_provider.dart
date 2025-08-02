import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/advanced_report_service.dart';
import '../models/advanced_report.dart';

final advancedReportServiceProvider = Provider<AdvancedReportService>((ref) {
  return AdvancedReportService();
});

final profitabilityReportProvider = FutureProvider.family<ProfitabilityData, Map<String, DateTime>>((ref, dateRange) async {
  final service = ref.read(advancedReportServiceProvider);
  return await service.generateProfitabilityReport(
    startDate: dateRange['startDate']!,
    endDate: dateRange['endDate']!,
  );
});

final trendAnalysisProvider = FutureProvider.family<TrendData, Map<String, DateTime>>((ref, dateRange) async {
  final service = ref.read(advancedReportServiceProvider);
  return await service.generateTrendAnalysis(
    startDate: dateRange['startDate']!,
    endDate: dateRange['endDate']!,
  );
});

final topCustomersProvider = FutureProvider.family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, params) async {
  final service = ref.read(advancedReportServiceProvider);
  return await service.generateTopCustomersReport(
    startDate: params['startDate'] as DateTime,
    endDate: params['endDate'] as DateTime,
    limit: params['limit'] as int? ?? 10,
  );
});

final paymentMethodsAnalysisProvider = FutureProvider.family<Map<String, dynamic>, Map<String, DateTime>>((ref, dateRange) async {
  final service = ref.read(advancedReportServiceProvider);
  return await service.generatePaymentMethodsAnalysis(
    startDate: dateRange['startDate']!,
    endDate: dateRange['endDate']!,
  );
});

final inventoryAnalysisProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.read(advancedReportServiceProvider);
  return await service.generateInventoryTurnoverAnalysis();
});
