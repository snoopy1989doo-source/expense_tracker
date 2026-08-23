import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/transaction_item.dart';

abstract class TransactionRepository {
  Future<List<TransactionItem>> getTransactions(String userId);
  Future<void> saveTransaction(String userId, TransactionItem transaction);
  Future<void> deleteTransaction(String userId, String transactionId);
}

class FirestoreTransactionRepository implements TransactionRepository {
  final FirebaseFirestore _firestore;
  final SharedPreferences _prefs;
  bool _useLocalMock = false;

  FirestoreTransactionRepository(this._firestore, this._prefs) {
    try {
      _firestore.app;
    } catch (_) {
      _useLocalMock = true;
    }
  }

  @override
  Future<List<TransactionItem>> getTransactions(String userId) async {
    if (_useLocalMock || userId == 'guest_user') {
      return _getLocalTransactions(userId);
    }
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionItem.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return _getLocalTransactions(userId);
    }
  }

  @override
  Future<void> saveTransaction(String userId, TransactionItem transaction) async {
    if (_useLocalMock || userId == 'guest_user') {
      await _saveLocalTransaction(userId, transaction);
      return;
    }
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toMap(), SetOptions(merge: true));
    } catch (e) {
      await _saveLocalTransaction(userId, transaction);
    }
  }

  @override
  Future<void> deleteTransaction(String userId, String transactionId) async {
    if (_useLocalMock || userId == 'guest_user') {
      await _deleteLocalTransaction(userId, transactionId);
      return;
    }
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      await _deleteLocalTransaction(userId, transactionId);
    }
  }

  // --- Local Storage Helpers ---

  Future<List<TransactionItem>> _getLocalTransactions(String userId) async {
    final key = 'local_transactions_$userId';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) {
      return [];
    }
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((item) => TransactionItem.fromMap(item as Map<String, dynamic>, item['id'] ?? ''))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Descending by date
  }

  Future<void> _saveLocalTransaction(String userId, TransactionItem transaction) async {
    final key = 'local_transactions_$userId';
    final list = await _getLocalTransactions(userId);
    final index = list.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) {
      list[index] = transaction;
    } else {
      list.add(transaction);
    }
    final encoded = jsonEncode(list.map((t) => t.toMap()).toList());
    await _prefs.setString(key, encoded);
  }

  Future<void> _deleteLocalTransaction(String userId, String transactionId) async {
    final key = 'local_transactions_$userId';
    final list = await _getLocalTransactions(userId);
    list.removeWhere((t) => t.id == transactionId);
    final encoded = jsonEncode(list.map((t) => t.toMap()).toList());
    await _prefs.setString(key, encoded);
  }
}
