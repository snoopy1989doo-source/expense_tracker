import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_item.dart';

abstract class TransactionRepository {
  Future<List<TransactionItem>> getTransactions(String roomId);
  Future<void> saveTransaction(String roomId, TransactionItem transaction);
  Future<void> deleteTransaction(String roomId, String transactionId);
}

class FirestoreTransactionRepository implements TransactionRepository {
  final FirebaseFirestore? _firestore;
  final SharedPreferences _prefs;
  bool _useLocalMock = false;

  FirestoreTransactionRepository(this._firestore, this._prefs) {
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
  Future<List<TransactionItem>> getTransactions(String roomId) async {
    if (_useLocalMock || roomId == 'guest_user') {
      return _getLocalTransactions(roomId);
    }
    try {
      final snapshot = await _firestore!
          .collection('couple_rooms')
          .doc(roomId)
          .collection('transactions')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionItem.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return _getLocalTransactions(roomId);
    }
  }

  @override
  Future<void> saveTransaction(String roomId, TransactionItem transaction) async {
    if (_useLocalMock || roomId == 'guest_user') {
      await _saveLocalTransaction(roomId, transaction);
      return;
    }
    try {
      await _firestore!
          .collection('couple_rooms')
          .doc(roomId)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toMap(), SetOptions(merge: true));
    } catch (e) {
      await _saveLocalTransaction(roomId, transaction);
    }
  }

  @override
  Future<void> deleteTransaction(String roomId, String transactionId) async {
    if (_useLocalMock || roomId == 'guest_user') {
      await _deleteLocalTransaction(roomId, transactionId);
      return;
    }
    try {
      await _firestore!
          .collection('couple_rooms')
          .doc(roomId)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      await _deleteLocalTransaction(roomId, transactionId);
    }
  }

  // --- Local Storage Helpers ---

  Future<List<TransactionItem>> _getLocalTransactions(String roomId) async {
    final key = 'local_transactions_';
    final jsonStr = _prefs.getString(key);
    if (jsonStr == null) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded
        .map((item) => TransactionItem.fromMap(item as Map<String, dynamic>, item['id'] ?? ''))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _saveLocalTransaction(String roomId, TransactionItem transaction) async {
    final key = 'local_transactions_';
    final list = await _getLocalTransactions(roomId);
    final index = list.indexWhere((t) => t.id == transaction.id);
    if (index >= 0) {
      list[index] = transaction;
    } else {
      list.add(transaction);
    }
    final encoded = jsonEncode(list.map((t) => t.toMap()).toList());
    await _prefs.setString(key, encoded);
  }

  Future<void> _deleteLocalTransaction(String roomId, String transactionId) async {
    final key = 'local_transactions_';
    final list = await _getLocalTransactions(roomId);
    list.removeWhere((t) => t.id == transactionId);
    final encoded = jsonEncode(list.map((t) => t.toMap()).toList());
    await _prefs.setString(key, encoded);
  }
}
