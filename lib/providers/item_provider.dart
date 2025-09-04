import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart';
import '../repositories/item_repository.dart';

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository();
});

final itemsProvider = FutureProvider<List<Item>>((ref) async {
  final repository = ref.read(itemRepositoryProvider);
  return await repository.getAllItems();
});

final itemsByLocationProvider = FutureProvider.family<List<Item>, ItemLocation>(
  (ref, location) async {
    final repository = ref.read(itemRepositoryProvider);
    return await repository.getAllItems(location: location);
  },
);

final itemsByStatusProvider = FutureProvider.family<List<Item>, ItemStatus>((
  ref,
  status,
) async {
  final repository = ref.read(itemRepositoryProvider);
  return await repository.getItemsByStatus(status.name);
});

final itemByCategoryProvider = FutureProvider.family<List<Item>, int>((
  ref,
  categoryId,
) async {
  final repository = ref.read(itemRepositoryProvider);
  return await repository.getItemsByCategoryId(categoryId);
});

final itemByIdProvider = FutureProvider.family<Item?, int>((ref, id) async {
  final repository = ref.read(itemRepositoryProvider);
  return await repository.getItemById(id);
});

final inventoryStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.read(itemRepositoryProvider);
  return await repository.getInventoryStats();
});

class ItemNotifier extends StateNotifier<AsyncValue<List<Item>>> {
  ItemNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadItems();
  }

  final ItemRepository _repository;

  Future<void> loadItems() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.getAllItems();
      state = AsyncValue.data(items);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addItem(Item item) async {
    try {
      await _repository.insertItem(item);
      await loadItems(); // إعادة تحميل القائمة
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateItem(Item item) async {
    try {
      await _repository.updateItem(item);
      await loadItems(); // إعادة تحميل القائمة
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      await _repository.deleteItem(id);
      await loadItems(); // إعادة تحميل القائمة
    } catch (error) {
      rethrow;
    }
  }

  Future<void> linkRfidTag(int itemId, String rfidTag) async {
    try {
      await _repository.linkRfidTag(itemId, rfidTag);
      await loadItems(); // إعادة تحميل القائمة
    } catch (error) {
      rethrow;
    }
  }

  Future<String> generateNextSku() async {
    return await _repository.generateNextSku();
  }

  void refresh() {
    loadItems();
  }
}

final itemNotifierProvider =
    StateNotifierProvider<ItemNotifier, AsyncValue<List<Item>>>((ref) {
      final repository = ref.read(itemRepositoryProvider);
      return ItemNotifier(repository);
    });
