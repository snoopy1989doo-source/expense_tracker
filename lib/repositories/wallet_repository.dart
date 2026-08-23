import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/wallet.dart';
import '../core/constants/default_categories.dart';

abstract class WalletRepository {
  Future<List<Wallet>> getWallets(String userId);
  Future<void> saveWallet(String userId, Wallet wallet);
  Future<void> deleteWallet(String userId, String walletId);
  Future<void> seedDefaultWallets(String userId);
}

class FirestoreWalletRepository implements WalletRepository {
  final FirebaseFirestore? _firestore;
  final SharedPreferences _prefs;
  bool _useLocalMock = false;

  FirestoreWalletRepository(this._firestore, this._prefs) {
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

  @override
  Future<List<Wallet>> getWallets(String userId) async {
    if (_useLocalMock || userId == 'guest_user') {
      return _getLocalWallets(userId);
    }
    try {
      final snapshot = await _firestore!
          .collection('users')
          .doc(userId)
          .collection('wallets')
          .orderBy('createdAt')
          .get();

      if (snapshot.docs.isEmpty) {
        await seedDefaultWallets(userId);
        return getWallets(userId);
      }

      return snapshot.docs
          .map((doc) => Wallet.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return _getLocalWallets(userId);
    }
  }

  @override
  Future<void> saveWallet(String userId, Wallet wallet) async {
    if (_useLocalMock || userId == 'guest_user') {
      await _saveLocalWallet(userId, wallet);
      return;
    }
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('wallets')
          .doc(wallet.id)
          .set(wallet.toMap(), SetOptions(merge: true));
    } catch (e) {
      await _saveLocalWallet(userId, wallet);
    }
  }

  @override
  Future<void> deleteWallet(String userId, String walletId) async {
    if (_useLocalMock || userId == 'guest_user') {
      await _deleteLocalWallet(userId, walletId);
      return;
    }
    try {
      await _firestore!
          .collection('users')
          .doc(userId)
          .collection('wallets')
          .doc(walletId)
          .delete();
    } catch (e) {
      await _deleteLocalWallet(userId, walletId);
    }
  }

  @override
  Future<void> seedDefaultWallets(String userId) async {
    for (var wData in DefaultCategoriesData.defaultWallets) {
      final wallet = Wallet(
        id: wData['id'],
        name: wData['name'],
        color: wData['color'],
        icon: wData['icon'],
        startingBalance: wData['startingBalance'],
        currentBalance: wData['startingBalance'],
        createdAt: DateTime.now(),
      );
      await saveWallet(userId, wallet);
    }
  }

  // --- Local Storage Helpers ---

  Future<List<Wallet>> _getLocalWallets(String userId) async {
    final key = 'local_wallets_$userId';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) {
      await seedDefaultWallets(userId);
      return _getLocalWallets(userId);
    }
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((item) => Wallet.fromMap(item as Map<String, dynamic>, item['id'] ?? ''))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> _saveLocalWallet(String userId, Wallet wallet) async {
    final key = 'local_wallets_$userId';
    final list = await _getLocalWallets(userId);
    final index = list.indexWhere((w) => w.id == wallet.id);
    if (index >= 0) {
      list[index] = wallet;
    } else {
      list.add(wallet);
    }
    final encoded = jsonEncode(list.map((w) => w.toMap()).toList());
    await _prefs.setString(key, encoded);
  }

  Future<void> _deleteLocalWallet(String userId, String walletId) async {
    final key = 'local_wallets_$userId';
    final list = await _getLocalWallets(userId);
    list.removeWhere((w) => w.id == walletId);
    final encoded = jsonEncode(list.map((w) => w.toMap()).toList());
    await _prefs.setString(key, encoded);
  }
}
