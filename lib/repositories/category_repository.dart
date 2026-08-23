import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/main_category.dart';
import '../../models/sub_category.dart';
import '../core/constants/default_categories.dart';

abstract class CategoryRepository {
  Future<List<MainCategory>> getMainCategories(String userId);
  Future<void> saveMainCategory(String userId, MainCategory category);
  Future<void> deleteMainCategory(String userId, String categoryId);

  Future<List<SubCategory>> getSubCategories(String userId);
  Future<void> saveSubCategory(String userId, SubCategory category);
  Future<void> deleteSubCategory(String userId, String subCategoryId);
  Future<void> seedDefaultCategories(String userId);
}

class FirestoreCategoryRepository implements CategoryRepository {
  final FirebaseFirestore? _firestore;
  final SharedPreferences _prefs;
  bool _useLocalMock = false;

  FirestoreCategoryRepository(this._firestore, this._prefs) {
    if (_firestore == null) {
      _useLocalMock = true;
    } else {
      try {
        _firestore.app;
      } catch (_) {
        _useLocalMock = true;
      }
    }
  }

  // --- Main Categories ---

  @override
  Future<List<MainCategory>> getMainCategories(String userId) async {
    if (_useLocalMock || userId == 'guest_user') {
      return _getLocalMainCategories(userId);
    }
    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('mainCategories')
          .orderBy('order')
          .get();
      
      if (snapshot.docs.isEmpty) {
        // If empty, automatically seed defaults and retrieve again
        await seedDefaultCategories(userId);
        return getMainCategories(userId);
      }

      return snapshot.docs
          .map((doc) => MainCategory.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      // Fallback to local on connection/permission errors
      return _getLocalMainCategories(userId);
    }
  }

  @override
  Future<void> saveMainCategory(String userId, MainCategory category) async {
    if (_useLocalMock || userId == 'guest_user') {
      await _saveLocalMainCategory(userId, category);
      return;
    }
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('mainCategories')
          .doc(category.id)
          .set(category.toMap(), SetOptions(merge: true));
    } catch (e) {
      await _saveLocalMainCategory(userId, category);
    }
  }

  @override
  Future<void> deleteMainCategory(String userId, String categoryId) async {
    if (_useLocalMock || userId == 'guest_user') {
      await _deleteLocalMainCategory(userId, categoryId);
      return;
    }
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('mainCategories')
          .doc(categoryId)
          .delete();
      
      // Cascade delete: delete all subcategories belonging to this category
      final subCats = await getSubCategories(userId);
      for (var sub in subCats) {
        if (sub.mainCategoryId == categoryId) {
          await deleteSubCategory(userId, sub.id);
        }
      }
    } catch (e) {
      await _deleteLocalMainCategory(userId, categoryId);
    }
  }

  // --- Sub Categories ---

  @override
  Future<List<SubCategory>> getSubCategories(String userId) async {
    if (_useLocalMock || userId == 'guest_user') {
      return _getLocalSubCategories(userId);
    }
    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('subCategories')
          .orderBy('order')
          .get();

      return snapshot.docs
          .map((doc) => SubCategory.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return _getLocalSubCategories(userId);
    }
  }

  @override
  Future<void> saveSubCategory(String userId, SubCategory category) async {
    if (_useLocalMock || userId == 'guest_user') {
      await _saveLocalSubCategory(userId, category);
      return;
    }
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('subCategories')
          .doc(category.id)
          .set(category.toMap(), SetOptions(merge: true));
    } catch (e) {
      await _saveLocalSubCategory(userId, category);
    }
  }

  @override
  Future<void> deleteSubCategory(String userId, String subCategoryId) async {
    if (_useLocalMock || userId == 'guest_user') {
      await _deleteLocalSubCategory(userId, subCategoryId);
      return;
    }
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('subCategories')
          .doc(subCategoryId)
          .delete();
    } catch (e) {
      await _deleteLocalSubCategory(userId, subCategoryId);
    }
  }

  @override
  Future<void> seedDefaultCategories(String userId) async {
    for (var defaultCat in DefaultCategoriesData.defaultList) {
      final mainCat = MainCategory(
        id: defaultCat.id,
        name: defaultCat.name,
        color: defaultCat.colorHex,
        emoji: defaultCat.emoji,
        order: defaultCat.order,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await saveMainCategory(userId, mainCat);

      for (var defaultSub in defaultCat.subCategories) {
        final subCat = SubCategory(
          id: defaultSub.id,
          mainCategoryId: defaultCat.id,
          name: defaultSub.name,
          emoji: defaultSub.emoji,
          color: defaultCat.colorHex, // inherit
          order: defaultSub.order,
        );
        await saveSubCategory(userId, subCat);
      }
    }
  }

  // --- Local JSON Storage Helpers ---

  Future<List<MainCategory>> _getLocalMainCategories(String userId) async {
    final key = 'local_main_categories_$userId';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) {
      // Seed first time locally
      await seedDefaultCategories(userId);
      return _getLocalMainCategories(userId);
    }
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((item) => MainCategory.fromMap(item as Map<String, dynamic>, item['id'] ?? ''))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> _saveLocalMainCategory(String userId, MainCategory category) async {
    final key = 'local_main_categories_$userId';
    final list = await _getLocalMainCategories(userId);
    final index = list.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      list[index] = category;
    } else {
      list.add(category);
    }
    final encoded = jsonEncode(list.map((c) => c.toMap()).toList());
    await _prefs.setString(key, encoded);
  }

  Future<void> _deleteLocalMainCategory(String userId, String categoryId) async {
    final key = 'local_main_categories_$userId';
    final list = await _getLocalMainCategories(userId);
    list.removeWhere((c) => c.id == categoryId);
    final encoded = jsonEncode(list.map((c) => c.toMap()).toList());
    await _prefs.setString(key, encoded);

    // Cascade delete sub categories locally
    final subCats = await _getLocalSubCategories(userId);
    final updatedSubs = subCats.where((sub) => sub.mainCategoryId != categoryId).toList();
    await _saveLocalSubCategoriesList(userId, updatedSubs);
  }

  Future<List<SubCategory>> _getLocalSubCategories(String userId) async {
    final key = 'local_sub_categories_$userId';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) {
      return [];
    }
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((item) => SubCategory.fromMap(item as Map<String, dynamic>, item['id'] ?? ''))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> _saveLocalSubCategory(String userId, SubCategory category) async {
    final key = 'local_sub_categories_$userId';
    final list = await _getLocalSubCategories(userId);
    final index = list.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      list[index] = category;
    } else {
      list.add(category);
    }
    final encoded = jsonEncode(list.map((c) => c.toMap()).toList());
    await _prefs.setString(key, encoded);
  }

  Future<void> _deleteLocalSubCategory(String userId, String subCategoryId) async {
    final key = 'local_sub_categories_$userId';
    final list = await _getLocalSubCategories(userId);
    list.removeWhere((c) => c.id == subCategoryId);
    final encoded = jsonEncode(list.map((c) => c.toMap()).toList());
    await _prefs.setString(key, encoded);
  }

  Future<void> _saveLocalSubCategoriesList(String userId, List<SubCategory> list) async {
    final key = 'local_sub_categories_$userId';
    final encoded = jsonEncode(list.map((c) => c.toMap()).toList());
    await _prefs.setString(key, encoded);
  }
}
