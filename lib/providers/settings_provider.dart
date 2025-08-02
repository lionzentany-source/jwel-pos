import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/settings_repository.dart';
import 'material_provider.dart';
import '../models/material.dart' as app_mat;

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final goldPriceProvider = Provider<double>((ref) {
  final materials = ref.watch(materialNotifierProvider).maybeWhen(
        data: (list) => list,
        orElse: () => <app_mat.Material>[],
      );
  if (materials.isEmpty) return 0.0;
  final gold = materials.firstWhere(
    (m) => m.nameAr == 'ذهب',
    orElse: () => materials.first,
  );
  return gold.isVariable ? gold.pricePerGram : 0.0;
});

final silverPriceProvider = Provider<double>((ref) {
  final materials = ref.watch(materialNotifierProvider).maybeWhen(
        data: (list) => list,
        orElse: () => <app_mat.Material>[],
      );
  if (materials.isEmpty) return 0.0;
  final silver = materials.firstWhere(
    (m) => m.nameAr == 'فضة',
    orElse: () => materials.first,
  );
  return silver.isVariable ? silver.pricePerGram : 0.0;
});

final storeNameProvider = FutureProvider<String>((ref) async {
  final repository = ref.read(settingsRepositoryProvider);
  return await repository.getStoreName() ?? 'My Store'; // Provide a default value
});

final currencyProvider = FutureProvider<String>((ref) async {
  final repository = ref.read(settingsRepositoryProvider);
  return await repository.getCurrency() ?? 'USD'; // Provide a default value
});

class SettingsNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  SettingsNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  final SettingsRepository _repository;
  final Ref _ref;

  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      // الأسعار باتت تعتمد على جدول المواد المتغيرة
      final materials = await _ref.read(materialRepositoryProvider).getAllMaterials();
      final gold = materials.firstWhere(
        (m) => m.nameAr == 'ذهب',
        orElse: () => app_mat.Material(nameAr: 'ذهب', isVariable: true, pricePerGram: 200),
      );
      final silver = materials.firstWhere(
        (m) => m.nameAr == 'فضة',
        orElse: () => app_mat.Material(nameAr: 'فضة', isVariable: true, pricePerGram: 5),
      );
      final goldPrice = gold.pricePerGram;
      final silverPrice = silver.pricePerGram;
      final storeName = await _repository.getStoreName() ?? 'مجوهرات جوهر';
      final currency = await _repository.getCurrency() ?? 'د.ل';
      final taxRate = await _repository.getTaxRate() ?? 0.0;

      state = AsyncValue.data({
        'gold_price_per_gram': goldPrice,
        'silver_price_per_gram': silverPrice,
        'store_name': storeName,
        'currency': currency,
        'tax_rate': taxRate,
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateGoldPrice(double price) async {
    try {
      await _repository.setGoldPrice(price);
      await loadSettings(); // إعادة تحميل الإعدادات
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateSilverPrice(double price) async {
    try {
      await _repository.setSilverPrice(price);
      await loadSettings(); // إعادة تحميل الإعدادات
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateStoreName(String name) async {
    try {
      await _repository.setStoreName(name);
      await loadSettings(); // إعادة تحميل الإعدادات
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateTaxRate(double rate) async {
    try {
      await _repository.setTaxRate(rate);
      await loadSettings(); // إعادة تحميل الإعدادات
    } catch (error) {
      rethrow;
    }
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<Map<String, dynamic>>>(
  (ref) => SettingsNotifier(ref.read(settingsRepositoryProvider), ref),
);
