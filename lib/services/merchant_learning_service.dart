import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MerchantMemory {
  final String name;
  final String mainCategoryId;
  final String? subCategoryId;
  final int count; // Capped at 5 to prevent database bloat
  final DateTime lastUpdated;

  MerchantMemory({
    required this.name,
    required this.mainCategoryId,
    this.subCategoryId,
    this.count = 1,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mainCategoryId': mainCategoryId,
      'subCategoryId': subCategoryId,
      'count': count,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory MerchantMemory.fromMap(Map<String, dynamic> map) {
    return MerchantMemory(
      name: map['name'] ?? '',
      mainCategoryId: map['mainCategoryId'] ?? '',
      subCategoryId: map['subCategoryId'],
      count: (map['count'] as num?)?.toInt() ?? 1,
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class MerchantLearningService {
  static const String _prefKey = 'ai_merchant_memory_cache_v1';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Predict category based on learned history (quietly in background)
  static Future<MerchantMemory?> predictCategory({
    required String receiverOrMerchantName,
    String? householdId,
  }) async {
    final cleanName = _cleanKey(receiverOrMerchantName);
    if (cleanName.length < 2) return null;

    try {
      // 1. Check local cache first (0ms)
      final prefs = await SharedPreferences.getInstance();
      final rawCache = prefs.getString(_prefKey);
      if (rawCache != null) {
        final Map<String, dynamic> cacheMap = jsonDecode(rawCache);
        for (var entry in cacheMap.entries) {
          if (_matchName(cleanName, entry.key)) {
            final data = entry.value as Map<String, dynamic>;
            return MerchantMemory(
              name: data['name'] ?? entry.key,
              mainCategoryId: data['mainCategoryId'] ?? '',
              subCategoryId: data['subCategoryId'],
              count: data['count'] ?? 1,
              lastUpdated: DateTime.now(),
            );
          }
        }
      }

      // 2. Check Firestore if householdId provided
      if (householdId != null && householdId.isNotEmpty) {
        final doc = await _firestore
            .collection('households')
            .doc(householdId)
            .collection('ai_merchant_memory')
            .doc(cleanName)
            .get();

        if (doc.exists && doc.data() != null) {
          return MerchantMemory.fromMap(doc.data()!);
        }
      }
    } catch (e) {
      debugPrint('AI Merchant Predict Notice: $e');
    }
    return null;
  }

  /// Learn / record category choice (Capped at 5 records per name to prevent bloating)
  static Future<void> learnMerchantCategory({
    required String receiverOrMerchantName,
    required String mainCategoryId,
    String? subCategoryId,
    String? householdId,
  }) async {
    final cleanName = _cleanKey(receiverOrMerchantName);
    if (cleanName.length < 2 || mainCategoryId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawCache = prefs.getString(_prefKey);
      Map<String, dynamic> cacheMap = {};
      if (rawCache != null) {
        try {
          cacheMap = jsonDecode(rawCache);
        } catch (_) {}
      }

      int currentCount = 0;
      if (cacheMap.containsKey(cleanName)) {
        currentCount = (cacheMap[cleanName]['count'] as num?)?.toInt() ?? 0;
      }

      // Capped at 5 entries max as requested by user
      if (currentCount >= 5) {
        debugPrint('AI Memory for $cleanName already saturated (5 samples). Skipping to save storage.');
        return;
      }

      final updatedData = {
        'name': receiverOrMerchantName.trim(),
        'mainCategoryId': mainCategoryId,
        'subCategoryId': subCategoryId,
        'count': currentCount + 1,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      cacheMap[cleanName] = updatedData;
      await prefs.setString(_prefKey, jsonEncode(cacheMap));

      // Quietly sync to Firestore
      if (householdId != null && householdId.isNotEmpty) {
        await _firestore
            .collection('households')
            .doc(householdId)
            .collection('ai_merchant_memory')
            .doc(cleanName)
            .set({
          'name': receiverOrMerchantName.trim(),
          'mainCategoryId': mainCategoryId,
          'subCategoryId': subCategoryId,
          'count': currentCount + 1,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('AI Merchant Learn Notice: $e');
    }
  }

  static String _cleanKey(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\sก-๙]'), '')
        .replaceAll(' ', '_')
        .toLowerCase()
        .trim();
  }

  static bool _matchName(String query, String target) {
    final q = query.toLowerCase();
    final t = target.toLowerCase();
    return q.contains(t) || t.contains(q);
  }
}
