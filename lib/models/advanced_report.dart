class AdvancedReport {
  final String id;
  final String title;
  final ReportType type;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  AdvancedReport({
    required this.id,
    required this.title,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.data,
    required this.createdAt,
  });
}

enum ReportType {
  profitability,
  trends,
  comparison,
  topCustomers,
  cashFlow,
  paymentMethods,
  inventory,
  slowMoving,
}

extension ReportTypeExtension on ReportType {
  String get displayName {
    switch (this) {
      case ReportType.profitability:
        return 'تقرير الربحية';
      case ReportType.trends:
        return 'تحليل الاتجاهات';
      case ReportType.comparison:
        return 'مقارنة الأداء';
      case ReportType.topCustomers:
        return 'أفضل العملاء';
      case ReportType.cashFlow:
        return 'التدفق النقدي';
      case ReportType.paymentMethods:
        return 'طرق الدفع';
      case ReportType.inventory:
        return 'تحليل المخزون';
      case ReportType.slowMoving:
        return 'الأصناف البطيئة';
    }
  }

  String get icon {
    switch (this) {
      case ReportType.profitability:
        return '💰';
      case ReportType.trends:
        return '📈';
      case ReportType.comparison:
        return '📊';
      case ReportType.topCustomers:
        return '👥';
      case ReportType.cashFlow:
        return '💸';
      case ReportType.paymentMethods:
        return '💳';
      case ReportType.inventory:
        return '📦';
      case ReportType.slowMoving:
        return '🐌';
    }
  }
}

class ProfitabilityData {
  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final double profitMargin;
  final List<CategoryProfit> categoryProfits;

  ProfitabilityData({
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.profitMargin,
    required this.categoryProfits,
  });
}

class CategoryProfit {
  final String categoryName;
  final double revenue;
  final double cost;
  final double profit;
  final double margin;

  CategoryProfit({
    required this.categoryName,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.margin,
  });
}

class TrendData {
  final List<DailySales> dailySales;
  final List<MonthlySales> monthlySales;
  final double growthRate;
  final String trend;

  TrendData({
    required this.dailySales,
    required this.monthlySales,
    required this.growthRate,
    required this.trend,
  });
}

class DailySales {
  final DateTime date;
  final double sales;
  final int invoiceCount;

  DailySales({
    required this.date,
    required this.sales,
    required this.invoiceCount,
  });
}

class MonthlySales {
  final int month;
  final int year;
  final double sales;
  final int invoiceCount;

  MonthlySales({
    required this.month,
    required this.year,
    required this.sales,
    required this.invoiceCount,
  });
}
