import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/material.dart';
import '../repositories/material_repository.dart';

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  return MaterialRepository();
});

final materialsProvider = FutureProvider<List<Material>>((ref) async {
  final repository = ref.read(materialRepositoryProvider);
  return await repository.getAllMaterials();
});

final variableMaterialsProvider = FutureProvider<List<Material>>((ref) async {
  final repository = ref.read(materialRepositoryProvider);
  return await repository.getVariableMaterials();
});

final materialByIdProvider = FutureProvider.family<Material?, int>((ref, id) async {
  final repository = ref.read(materialRepositoryProvider);
  return await repository.getMaterialById(id);
});

class MaterialNotifier extends StateNotifier<AsyncValue<List<Material>>> {
  MaterialNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadMaterials();
  }

  final MaterialRepository _repository;

  Future<void> loadMaterials() async {
    state = const AsyncValue.loading();
    try {
      final materials = await _repository.getAllMaterials();
      state = AsyncValue.data(materials);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addMaterial(Material material) async {
    try {
      await _repository.insertMaterial(material);
      await loadMaterials(); // إعادة تحميل القائمة
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateMaterial(Material material) async {
    try {
      await _repository.updateMaterial(material);
      await loadMaterials(); // إعادة تحميل القائمة
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateMaterialPrice(int materialId, double newPrice) async {
    try {
      await _repository.updateMaterialPrice(materialId, newPrice);
      await loadMaterials();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteMaterial(int id) async {
    try {
      await _repository.deleteMaterial(id);
      await loadMaterials(); // إعادة تحميل القائمة
    } catch (error) {
      rethrow;
    }
  }
}

final materialNotifierProvider = StateNotifierProvider<MaterialNotifier, AsyncValue<List<Material>>>((ref) {
  final repository = ref.read(materialRepositoryProvider);
  return MaterialNotifier(repository);
});
