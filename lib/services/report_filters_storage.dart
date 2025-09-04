import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/invoice.dart';

class ReportFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final ItemLocation? inventoryLocation;
  final bool groupByLocation;
  final int? categoryId;
  final PaymentMethod? paymentMethod;

  const ReportFilters({
    this.startDate,
    this.endDate,
    this.inventoryLocation,
    this.groupByLocation = false,
    this.categoryId,
    this.paymentMethod,
  });

  ReportFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    ItemLocation? inventoryLocation,
    bool? groupByLocation,
    int? categoryId,
    PaymentMethod? paymentMethod,
  }) => ReportFilters(
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    inventoryLocation: inventoryLocation ?? this.inventoryLocation,
    groupByLocation: groupByLocation ?? this.groupByLocation,
    categoryId: categoryId ?? this.categoryId,
    paymentMethod: paymentMethod ?? this.paymentMethod,
  );
}

class ReportFiltersStorage {
  static const _kStart = 'reports.startDate';
  static const _kEnd = 'reports.endDate';
  static const _kLoc = 'reports.inventoryLocation';
  static const _kGroup = 'reports.groupByLocation';
  static const _kCategory = 'reports.categoryId';
  static const _kPayment = 'reports.paymentMethod';

  static Future<ReportFilters> load() async {
    final sp = await SharedPreferences.getInstance();
    final startStr = sp.getString(_kStart);
    final endStr = sp.getString(_kEnd);
    final locStr = sp.getString(_kLoc);
    final group = sp.getBool(_kGroup) ?? false;
    final catId = sp.getInt(_kCategory);
    final paymentStr = sp.getString(_kPayment);

    DateTime? start = startStr != null ? DateTime.tryParse(startStr) : null;
    DateTime? end = endStr != null ? DateTime.tryParse(endStr) : null;
    ItemLocation? loc = locStr != null
        ? ItemLocation.values.firstWhere(
            (e) => e.name == locStr,
            orElse: () => ItemLocation.warehouse,
          )
        : null;
    PaymentMethod? pay = paymentStr != null
        ? PaymentMethod.values.firstWhere(
            (e) => e.name == paymentStr,
            orElse: () => PaymentMethod.cash,
          )
        : null;

    return ReportFilters(
      startDate: start,
      endDate: end,
      inventoryLocation: loc,
      groupByLocation: group,
      categoryId: catId,
      paymentMethod: pay,
    );
  }

  static Future<void> save(ReportFilters f) async {
    final sp = await SharedPreferences.getInstance();
    if (f.startDate != null) {
      await sp.setString(_kStart, f.startDate!.toIso8601String());
    }
    if (f.endDate != null) {
      await sp.setString(_kEnd, f.endDate!.toIso8601String());
    }
    await sp.setBool(_kGroup, f.groupByLocation);
    if (f.inventoryLocation != null) {
      await sp.setString(_kLoc, f.inventoryLocation!.name);
    } else {
      await sp.remove(_kLoc);
    }
    if (f.categoryId != null) {
      await sp.setInt(_kCategory, f.categoryId!);
    } else {
      await sp.remove(_kCategory);
    }
    if (f.paymentMethod != null) {
      await sp.setString(_kPayment, f.paymentMethod!.name);
    } else {
      await sp.remove(_kPayment);
    }
  }
}
