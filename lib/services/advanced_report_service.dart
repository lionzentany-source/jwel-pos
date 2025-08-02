import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/advanced_report.dart';
import '../models/item.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/item_repository.dart';
import '../repositories/customer_repository.dart';
import '../services/database_service.dart';

class AdvancedReportService {
  static final AdvancedReportService _instance =
      AdvancedReportService._internal();
  factory AdvancedReportService() => _instance;
  AdvancedReportService._internal();

  final InvoiceRepository _invoiceRepository = InvoiceRepository();
  final ItemRepository _itemRepository = ItemRepository();
  final CustomerRepository _customerRepository = CustomerRepository();
  final DatabaseService _databaseService = DatabaseService();

  /// تقرير الربحية المتقدم
  Future<ProfitabilityData> generateProfitabilityReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint("--- GENERATING PROFITABILITY REPORT ---");

      final invoices = await _invoiceRepository.getInvoicesByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      double totalRevenue = 0;
      double totalCost = 0;
      Map<String, CategoryProfit> categoryProfits = {};

      // حساب التكلفة الفعلية من عناصر الفواتير
      for (final invoice in invoices) {
        totalRevenue += invoice.total;

        // حساب التكلفة الفعلية من عناصر الفاتورة
        final invoiceCost = await _calculateInvoiceCost(invoice.id!);
        totalCost += invoiceCost;

        // إضافة إلى فئة عامة
        const categoryName = 'عام';
        if (categoryProfits.containsKey(categoryName)) {
          final existing = categoryProfits[categoryName]!;
          categoryProfits[categoryName] = CategoryProfit(
            categoryName: categoryName,
            revenue: existing.revenue + invoice.total,
            cost: existing.cost + invoiceCost,
            profit: existing.profit + (invoice.total - invoiceCost),
            margin: 0,
          );
        } else {
          categoryProfits[categoryName] = CategoryProfit(
            categoryName: categoryName,
            revenue: invoice.total,
            cost: invoiceCost,
            profit: invoice.total - invoiceCost,
            margin: 0,
          );
        }
      }

      // حساب هامش الربح لكل فئة
      final categoryProfitsList = categoryProfits.values.map((cp) {
        final margin = cp.revenue > 0 ? (cp.profit / cp.revenue) * 100 : 0.0;
        return CategoryProfit(
          categoryName: cp.categoryName,
          revenue: cp.revenue,
          cost: cp.cost,
          profit: cp.profit,
          margin: margin,
        );
      }).toList();

      final grossProfit = totalRevenue - totalCost;
      final profitMargin = totalRevenue > 0
          ? (grossProfit / totalRevenue) * 100
          : 0.0;

      return ProfitabilityData(
        totalRevenue: totalRevenue,
        totalCost: totalCost,
        grossProfit: grossProfit,
        profitMargin: profitMargin,
        categoryProfits: categoryProfitsList,
      );
    } catch (e) {
      debugPrint("Error generating profitability report: $e");
      rethrow;
    }
  }

  /// تحليل الاتجاهات الزمنية
  Future<TrendData> generateTrendAnalysis({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint("--- GENERATING TREND ANALYSIS ---");

      final invoices = await _invoiceRepository.getInvoicesByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      // تجميع المبيعات اليومية
      Map<String, DailySales> dailySalesMap = {};
      for (final invoice in invoices) {
        final dateKey =
            '${invoice.createdAt.year}-${invoice.createdAt.month}-${invoice.createdAt.day}';

        if (dailySalesMap.containsKey(dateKey)) {
          final existing = dailySalesMap[dateKey]!;
          dailySalesMap[dateKey] = DailySales(
            date: existing.date,
            sales: existing.sales + invoice.total,
            invoiceCount: existing.invoiceCount + 1,
          );
        } else {
          dailySalesMap[dateKey] = DailySales(
            date: invoice.createdAt,
            sales: invoice.total,
            invoiceCount: 1,
          );
        }
      }

      // تجميع المبيعات الشهرية
      Map<String, MonthlySales> monthlySalesMap = {};
      for (final invoice in invoices) {
        final monthKey = '${invoice.createdAt.year}-${invoice.createdAt.month}';

        if (monthlySalesMap.containsKey(monthKey)) {
          final existing = monthlySalesMap[monthKey]!;
          monthlySalesMap[monthKey] = MonthlySales(
            month: existing.month,
            year: existing.year,
            sales: existing.sales + invoice.total,
            invoiceCount: existing.invoiceCount + 1,
          );
        } else {
          monthlySalesMap[monthKey] = MonthlySales(
            month: invoice.createdAt.month,
            year: invoice.createdAt.year,
            sales: invoice.total,
            invoiceCount: 1,
          );
        }
      }

      // حساب معدل النمو
      final sortedMonthlySales = monthlySalesMap.values.toList()
        ..sort(
          (a, b) =>
              DateTime(a.year, a.month).compareTo(DateTime(b.year, b.month)),
        );

      double growthRate = 0;
      String trend = 'مستقر';

      if (sortedMonthlySales.length >= 2) {
        final firstMonth = sortedMonthlySales.first.sales;
        final lastMonth = sortedMonthlySales.last.sales;

        if (firstMonth > 0) {
          growthRate = ((lastMonth - firstMonth) / firstMonth) * 100;
          trend = growthRate > 5
              ? 'متزايد'
              : growthRate < -5
              ? 'متناقص'
              : 'مستقر';
        }
      }

      return TrendData(
        dailySales: dailySalesMap.values.toList()
          ..sort((a, b) => a.date.compareTo(b.date)),
        monthlySales: sortedMonthlySales,
        growthRate: growthRate,
        trend: trend,
      );
    } catch (e) {
      debugPrint("Error generating trend analysis: $e");
      rethrow;
    }
  }

  /// تقرير أفضل العملاء
  Future<List<Map<String, dynamic>>> generateTopCustomersReport({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
  }) async {
    try {
      debugPrint("--- GENERATING TOP CUSTOMERS REPORT ---");

      final invoices = await _invoiceRepository.getInvoicesByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      Map<int, Map<String, dynamic>> customerStats = {};

      for (final invoice in invoices) {
        if (invoice.customerId != null) {
          final customerId = invoice.customerId!;

          if (customerStats.containsKey(customerId)) {
            customerStats[customerId]!['totalSpent'] += invoice.total;
            customerStats[customerId]!['invoiceCount'] += 1;
            customerStats[customerId]!['lastPurchase'] = invoice.createdAt;
          } else {
            final customer = await _customerRepository.getCustomerById(
              customerId,
            );
            customerStats[customerId] = {
              'customerId': customerId,
              'customerName': customer?.name ?? 'عميل غير معروف',
              'customerPhone': customer?.phone ?? '',
              'totalSpent': invoice.total,
              'invoiceCount': 1,
              'firstPurchase': invoice.createdAt,
              'lastPurchase': invoice.createdAt,
            };
          }
        }
      }

      // ترتيب العملاء حسب إجمالي الإنفاق
      final sortedCustomers = customerStats.values.toList()
        ..sort((a, b) => b['totalSpent'].compareTo(a['totalSpent']));

      return sortedCustomers.take(limit).toList();
    } catch (e) {
      debugPrint("Error generating top customers report: $e");
      rethrow;
    }
  }

  /// تحليل طرق الدفع
  Future<Map<String, dynamic>> generatePaymentMethodsAnalysis({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint("--- GENERATING PAYMENT METHODS ANALYSIS ---");

      final invoices = await _invoiceRepository.getInvoicesByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      Map<String, double> paymentMethods = {'نقدي': 0, 'بطاقة': 0, 'تقسيط': 0};

      for (final invoice in invoices) {
        final paymentMethod = invoice.paymentMethod.displayName;
        paymentMethods[paymentMethod] =
            (paymentMethods[paymentMethod] ?? 0) + invoice.total;
      }

      final totalSales = paymentMethods.values.fold(
        0.0,
        (sum, value) => sum + value,
      );

      Map<String, double> percentages = {};
      paymentMethods.forEach((method, amount) {
        percentages[method] = totalSales > 0 ? (amount / totalSales) * 100 : 0;
      });

      return {
        'amounts': paymentMethods,
        'percentages': percentages,
        'totalSales': totalSales,
      };
    } catch (e) {
      debugPrint("Error generating payment methods analysis: $e");
      rethrow;
    }
  }

  /// تحليل دوران المخزون
  Future<Map<String, dynamic>> generateInventoryTurnoverAnalysis() async {
    try {
      debugPrint("--- GENERATING INVENTORY TURNOVER ANALYSIS ---");

      final items = await _itemRepository.getAllItems();
      final soldItems = items
          .where((item) => item.status == ItemStatus.sold)
          .toList();
      final inStockItems = items
          .where((item) => item.status == ItemStatus.inStock)
          .toList();

      // حساب قيمة المخزون
      double totalInventoryValue = 0;
      double soldInventoryValue = 0;

      for (final item in items) {
        final itemValue = _calculateItemValue(item);
        totalInventoryValue += itemValue;

        if (item.status == ItemStatus.sold) {
          soldInventoryValue += itemValue;
        }
      }

      // حساب معدل دوران المخزون
      final turnoverRate = totalInventoryValue > 0
          ? soldInventoryValue / totalInventoryValue
          : 0;

      // تحليل الفئات
      Map<String, Map<String, dynamic>> categoryAnalysis = {};
      for (final item in items) {
        const categoryName = 'عام'; // فئة عامة لجميع الأصناف

        if (!categoryAnalysis.containsKey(categoryName)) {
          categoryAnalysis[categoryName] = {
            'total': 0,
            'sold': 0,
            'inStock': 0,
            'value': 0.0,
          };
        }

        categoryAnalysis[categoryName]!['total'] += 1;
        categoryAnalysis[categoryName]!['value'] += _calculateItemValue(item);

        if (item.status == ItemStatus.sold) {
          categoryAnalysis[categoryName]!['sold'] += 1;
        } else if (item.status == ItemStatus.inStock) {
          categoryAnalysis[categoryName]!['inStock'] += 1;
        }
      }

      return {
        'totalItems': items.length,
        'soldItems': soldItems.length,
        'inStockItems': inStockItems.length,
        'totalInventoryValue': totalInventoryValue,
        'soldInventoryValue': soldInventoryValue,
        'turnoverRate': turnoverRate,
        'categoryAnalysis': categoryAnalysis,
      };
    } catch (e) {
      debugPrint("Error generating inventory turnover analysis: $e");
      rethrow;
    }
  }

  /// مقارنة الأداء بين الفترة الحالية والفترة السابقة المماثلة
  Future<Map<String, dynamic>> generateComparisonReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint("--- GENERATING COMPARISON REPORT ---");
      final periodDays = endDate.difference(startDate).inDays + 1;
      final prevEnd = startDate.subtract(const Duration(days: 1));
      final prevStart = prevEnd.subtract(Duration(days: periodDays - 1));

      final currentInvoices = await _invoiceRepository.getInvoicesByDateRange(
        startDate: startDate,
        endDate: endDate,
      );
      final previousInvoices = await _invoiceRepository.getInvoicesByDateRange(
        startDate: prevStart,
        endDate: prevEnd,
      );

      double currentTotal = 0;
      double previousTotal = 0;
      double currentDiscounts = 0;
      double previousDiscounts = 0;

      for (final inv in currentInvoices) {
        currentTotal += inv.total;
        currentDiscounts += inv.discount;
      }
      for (final inv in previousInvoices) {
        previousTotal += inv.total;
        previousDiscounts += inv.discount;
      }

      double salesGrowth = 0;
      double invoiceGrowth = 0;
      if (previousTotal > 0) {
        salesGrowth = ((currentTotal - previousTotal) / previousTotal) * 100;
      } else if (currentTotal > 0) {
        salesGrowth = 100;
      }
      if (previousInvoices.isNotEmpty) {
        invoiceGrowth =
            ((currentInvoices.length - previousInvoices.length) /
                previousInvoices.length) *
            100;
      } else if (currentInvoices.isNotEmpty) {
        invoiceGrowth = 100;
      }

      final currentAverage = currentInvoices.isNotEmpty
          ? currentTotal / currentInvoices.length
          : 0;
      final previousAverage = previousInvoices.isNotEmpty
          ? previousTotal / previousInvoices.length
          : 0;
      double avgGrowth = 0;
      if (previousAverage > 0) {
        avgGrowth =
            ((currentAverage - previousAverage) / previousAverage) * 100;
      } else if (currentAverage > 0) {
        avgGrowth = 100;
      }

      return {
        'period': {
          'currentStart': startDate,
          'currentEnd': endDate,
          'previousStart': prevStart,
          'previousEnd': prevEnd,
          'days': periodDays,
        },
        'current': {
          'totalSales': currentTotal,
          'invoiceCount': currentInvoices.length,
          'averageSale': currentAverage,
          'discounts': currentDiscounts,
        },
        'previous': {
          'totalSales': previousTotal,
          'invoiceCount': previousInvoices.length,
          'averageSale': previousAverage,
          'discounts': previousDiscounts,
        },
        'growth': {
          'salesGrowth': salesGrowth,
          'invoiceGrowth': invoiceGrowth,
          'averageGrowth': avgGrowth,
          'discountChange': previousDiscounts > 0
              ? ((currentDiscounts - previousDiscounts) / previousDiscounts) *
                    100
              : currentDiscounts > 0
              ? 100
              : 0,
        },
      };
    } catch (e) {
      debugPrint("Error generating comparison report: $e");
      rethrow;
    }
  }

  /// تقرير التدفق النقدي (تقديري اعتماداً على التكاليف والمبيعات)
  Future<Map<String, dynamic>> generateCashFlowReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint("--- GENERATING CASH FLOW REPORT ---");
      final invoices = await _invoiceRepository.getInvoicesByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      double cashIn = 0;
      double costOut = 0;
      Map<String, double> byMethod = {};

      for (final inv in invoices) {
        cashIn += inv.total;
        byMethod[inv.paymentMethod.displayName] =
            (byMethod[inv.paymentMethod.displayName] ?? 0) + inv.total;
        costOut += await _calculateInvoiceCost(inv.id!);
      }

      // مصروفات تشغيل (رواتب، كهرباء، إيجار ... إلخ)
      double operatingExpenses = 0;
      try {
        final db = await _databaseService.database;
        final result = await db.rawQuery(
          'SELECT SUM(amount) as total FROM expenses WHERE date BETWEEN ? AND ?',
          [startDate.toIso8601String(), endDate.toIso8601String()],
        );
        operatingExpenses = (result.first['total'] as num?)?.toDouble() ?? 0.0;
      } catch (e) {
        debugPrint('No expenses table yet or error reading expenses: $e');
      }

      final totalOut = costOut + operatingExpenses;
      final net = cashIn - totalOut;
      return {
        'cashIn': cashIn,
        'inventoryCost': costOut,
        'operatingExpenses': operatingExpenses,
        'cashOut': totalOut,
        'netCash': net,
        'byMethod': byMethod,
      };
    } catch (e) {
      debugPrint("Error generating cash flow report: $e");
      rethrow;
    }
  }

  /// تقرير الأصناف البطيئة (أقدم من thresholdDays ولم تُبع بعد)
  Future<Map<String, dynamic>> generateSlowMovingItemsReport({
    int thresholdDays = 30,
  }) async {
    try {
      debugPrint("--- GENERATING SLOW MOVING ITEMS REPORT ---");
      final items = await _itemRepository.getAllItems();
      final now = DateTime.now();
      final slow = items
          .where(
            (i) =>
                i.status == ItemStatus.inStock &&
                now.difference(i.createdAt).inDays >= thresholdDays,
          )
          .toList();
      slow.sort(
        (a, b) => now
            .difference(b.createdAt)
            .inDays
            .compareTo(now.difference(a.createdAt).inDays),
      );

      return {
        'thresholdDays': thresholdDays,
        'totalInStock': items
            .where((i) => i.status == ItemStatus.inStock)
            .length,
        'slowCount': slow.length,
        'slowPercentage':
            items.where((i) => i.status == ItemStatus.inStock).isNotEmpty
            ? (slow.length /
                      items
                          .where((i) => i.status == ItemStatus.inStock)
                          .length) *
                  100
            : 0,
        'items': slow
            .map(
              (i) => {
                'sku': i.sku,
                'weight': i.weightGrams,
                'karat': i.karat,
                'ageDays': now.difference(i.createdAt).inDays,
                'createdAt': i.createdAt,
              },
            )
            .toList(),
      };
    } catch (e) {
      debugPrint("Error generating slow moving items report: $e");
      rethrow;
    }
  }

  /// حساب تكلفة الفاتورة من عناصرها
  Future<double> _calculateInvoiceCost(int invoiceId) async {
    try {
      final db = await _databaseService.database;
      final result = await db.rawQuery(
        '''
        SELECT SUM(i.cost_price * ii.quantity) as total_cost
        FROM invoice_items ii
        JOIN items i ON ii.item_id = i.id
        WHERE ii.invoice_id = ?
        ''',
        [invoiceId],
      );

      return (result.first['total_cost'] as double?) ?? 0.0;
    } catch (e) {
      debugPrint('Error calculating invoice cost: $e');
      return 0.0;
    }
  }

  /// حساب قيمة الصنف
  double _calculateItemValue(Item item) {
    return item.weightGrams * 50 + item.workmanshipFee + item.stonePrice;
  }
}
