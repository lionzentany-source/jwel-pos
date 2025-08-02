import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final goldPriceProvider = FutureProvider<double>((ref) async {
  final repository = ref.read(settingsRepositoryProvider);
  return await repository.getGoldPrice();
});

final silverPriceProvider = FutureProvider<double>((ref) async {
  final repository = ref.read(settingsRepositoryProvider);
  return await repository.getSilverPrice();
});

final storeNameProvider = FutureProvider<String>((ref) async {
  final repository = ref.read(settingsRepositoryProvider);
  return await repository.getStoreName();
});

final currencyProvider = FutureProvider<String>((ref) async {
  final repository = ref.read(settingsRepositoryProvider);
  return await repository.getCurrency();
});

class SettingsNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  SettingsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  final SettingsRepository _repository;

  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      final goldPrice = await _repository.getGoldPrice();
      final silverPrice = await _repository.getSilverPrice();
      final storeName = await _repository.getStoreName();
      final currency = await _repository.getCurrency();
      final taxRate = await _repository.getTaxRate();

      state = AsyncValue.data({
        'goldPrice': goldPrice,
        'silverPrice': silverPrice,
        'storeName': storeName,
        'currency': currency,
        'taxRate': taxRate,
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

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  final repository = ref.read(settingsRepositoryProvider);
  return SettingsNotifier(repository);
});
