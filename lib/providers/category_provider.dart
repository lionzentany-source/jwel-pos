import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.read(categoryRepositoryProvider);
  return await repository.getAllCategories();
});

final categoryByIdProvider = FutureProvider.family<Category?, int>((ref, id) async {
  final repository = ref.read(categoryRepositoryProvider);
  return await repository.getCategoryById(id);
});

class CategoryNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  CategoryNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCategories();
  }

  final CategoryRepository _repository;

  Future<void> loadCategories() async {
    state = const AsyncValue.loading();
    try {
      final categories = await _repository.getAllCategories();
      state = AsyncValue.data(categories);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addCategory(Category category) async {
    try {
      await _repository.insertCategory(category);
      await loadCategories(); // إعادة تحميل القائمة
    } catch (error) {
      // يمكن إضافة معالجة الأخطاء هنا
      rethrow;
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      await _repository.updateCategory(category);
      await loadCategories(); // إعادة تحميل القائمة
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _repository.deleteCategory(id);
      await loadCategories(); // إعادة تحميل القائمة
    } catch (error) {
      rethrow;
    }
  }
}

final categoryNotifierProvider = StateNotifierProvider<CategoryNotifier, AsyncValue<List<Category>>>((ref) {
  final repository = ref.read(categoryRepositoryProvider);
  return CategoryNotifier(repository);
});
