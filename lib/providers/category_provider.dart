import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';
import 'auth_provider.dart';
import '../models/main_category.dart';
import '../models/sub_category.dart';
import '../repositories/category_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore?>((ref) {
  try {
    return Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;
  } catch (_) {
    return null;
  }
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirestoreCategoryRepository(firestore, prefs);
});

final mainCategoriesProvider = StateNotifierProvider<MainCategoriesNotifier, List<MainCategory>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final userId = authState.value;
  return MainCategoriesNotifier(repository, userId, ref);
});

final subCategoriesProvider = StateNotifierProvider<SubCategoriesNotifier, List<SubCategory>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final userId = authState.value;
  return SubCategoriesNotifier(repository, userId);
});

class MainCategoriesNotifier extends StateNotifier<List<MainCategory>> {
  final CategoryRepository _repository;
  final String? _userId;
  final Ref _ref;

  MainCategoriesNotifier(this._repository, this._userId, this._ref) : super([]) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    if (_userId == null) return;
    try {
      final list = await _repository.getMainCategories(_userId);
      state = list;
    } catch (_) {}
  }

  Future<void> addCategory(MainCategory category) async {
    if (_userId == null) return;
    await _repository.saveMainCategory(_userId, category);
    await loadCategories();
  }

  Future<void> updateCategory(MainCategory category) async {
    if (_userId == null) return;
    await _repository.saveMainCategory(_userId, category);
    await loadCategories();
    // Refresh subcategories as well, because subcategory color inherits maincategory color
    await _ref.read(subCategoriesProvider.notifier).loadSubCategories();
  }

  Future<void> deleteCategory(String categoryId) async {
    if (_userId == null) return;
    await _repository.deleteMainCategory(_userId, categoryId);
    await loadCategories();
    // Cascade reload subcategories
    await _ref.read(subCategoriesProvider.notifier).loadSubCategories();
  }

  Future<void> resetToDefault() async {
    if (_userId == null) return;
    await _repository.seedDefaultCategories(_userId);
    await loadCategories();
    await _ref.read(subCategoriesProvider.notifier).loadSubCategories();
  }
}

class SubCategoriesNotifier extends StateNotifier<List<SubCategory>> {
  final CategoryRepository _repository;
  final String? _userId;

  SubCategoriesNotifier(this._repository, this._userId) : super([]) {
    loadSubCategories();
  }

  Future<void> loadSubCategories() async {
    if (_userId == null) return;
    try {
      final list = await _repository.getSubCategories(_userId);
      state = list;
    } catch (_) {}
  }

  Future<void> addSubCategory(SubCategory category) async {
    if (_userId == null) return;
    await _repository.saveSubCategory(_userId, category);
    await loadSubCategories();
  }

  Future<void> updateSubCategory(SubCategory category) async {
    if (_userId == null) return;
    await _repository.saveSubCategory(_userId, category);
    await loadSubCategories();
  }

  Future<void> deleteSubCategory(String subCategoryId) async {
    if (_userId == null) return;
    await _repository.deleteSubCategory(_userId, subCategoryId);
    await loadSubCategories();
  }
}
