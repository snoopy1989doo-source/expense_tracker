import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'couple_provider.dart';
import 'theme_provider.dart';
import '../models/main_category.dart';
import '../models/sub_category.dart';
import '../repositories/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirestoreCategoryRepository(firestore, prefs);
});

final mainCategoriesProvider =
    StateNotifierProvider<MainCategoriesNotifier, List<MainCategory>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final userId = authState.value;
  final coupleRoomId = ref.watch(coupleRoomIdProvider);
  final effectiveId = coupleRoomId ?? userId;
  return MainCategoriesNotifier(repository, effectiveId, ref);
});

final subCategoriesProvider =
    StateNotifierProvider<SubCategoriesNotifier, List<SubCategory>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final userId = authState.value;
  final coupleRoomId = ref.watch(coupleRoomIdProvider);
  final effectiveId = coupleRoomId ?? userId;
  return SubCategoriesNotifier(repository, effectiveId);
});

class MainCategoriesNotifier extends StateNotifier<List<MainCategory>> {
  final CategoryRepository _repository;
  final String? _roomId;
  final Ref _ref;

  MainCategoriesNotifier(this._repository, this._roomId, this._ref) : super([]) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    if (_roomId == null) return;
    try {
      final list = await _repository.getMainCategories(_roomId);
      state = list;
    } catch (_) {}
  }

  Future<void> addCategory(MainCategory category) async {
    if (_roomId == null) return;
    await _repository.saveMainCategory(_roomId, category);
    await loadCategories();
  }

  Future<void> updateCategory(MainCategory category) async {
    if (_roomId == null) return;
    await _repository.saveMainCategory(_roomId, category);
    await loadCategories();
    await _ref.read(subCategoriesProvider.notifier).loadSubCategories();
  }

  Future<void> deleteCategory(String categoryId) async {
    if (_roomId == null) return;
    await _repository.deleteMainCategory(_roomId, categoryId);
    await loadCategories();
    await _ref.read(subCategoriesProvider.notifier).loadSubCategories();
  }

  Future<void> reorderCategories(List<MainCategory> reordered) async {
    if (_roomId == null) return;
    final updatedList = [
      for (int i = 0; i < reordered.length; i++)
        reordered[i].copyWith(order: i)
    ];
    state = updatedList;
    for (final updated in updatedList) {
      await _repository.saveMainCategory(_roomId, updated);
    }
  }

  Future<void> resetToDefault() async {
    if (_roomId == null) return;
    await _repository.seedDefaultCategories(_roomId);
    await loadCategories();
    await _ref.read(subCategoriesProvider.notifier).loadSubCategories();
  }
}

class SubCategoriesNotifier extends StateNotifier<List<SubCategory>> {
  final CategoryRepository _repository;
  final String? _roomId;

  SubCategoriesNotifier(this._repository, this._roomId) : super([]) {
    loadSubCategories();
  }

  Future<void> loadSubCategories() async {
    if (_roomId == null) return;
    try {
      final list = await _repository.getSubCategories(_roomId);
      state = list;
    } catch (_) {}
  }

  Future<void> reorderSubCategories(List<SubCategory> reordered) async {
    if (_roomId == null) return;
    // Pre-assign order to reordered items
    final updatedReordered = [
      for (int i = 0; i < reordered.length; i++)
        reordered[i].copyWith(order: i)
    ];
    final currentList = List<SubCategory>.from(state);
    final idsToUpdate = updatedReordered.map((s) => s.id).toSet();
    final remaining = currentList.where((s) => !idsToUpdate.contains(s.id)).toList();
    state = [...updatedReordered, ...remaining];

    for (final updated in updatedReordered) {
      await _repository.saveSubCategory(_roomId, updated);
    }
  }

  Future<void> addSubCategory(SubCategory category) async {
    if (_roomId == null) return;
    await _repository.saveSubCategory(_roomId, category);
    await loadSubCategories();
  }

  Future<void> updateSubCategory(SubCategory category) async {
    if (_roomId == null) return;
    await _repository.saveSubCategory(_roomId, category);
    await loadSubCategories();
  }

  Future<void> deleteSubCategory(String subCategoryId) async {
    if (_roomId == null) return;
    await _repository.deleteSubCategory(_roomId, subCategoryId);
    await loadSubCategories();
  }
}
