import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';
import 'auth_provider.dart';
import 'couple_provider.dart';
import '../models/transaction_item.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/storage_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirestoreTransactionRepository(firestore, prefs);
});

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return FirebaseStorageRepository(null);
});

final rawTransactionsProvider =
    StateNotifierProvider<RawTransactionsNotifier, List<TransactionItem>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final userId = authState.value;
  // Use coupleRoomId if available, fall back to userId (for guest/local mock)
  final coupleRoomId = ref.watch(coupleRoomIdProvider);
  final effectiveId = coupleRoomId ?? userId;
  return RawTransactionsNotifier(repository, effectiveId);
});

class TransactionFilters {
  final DateTime selectedMonth;
  final String? selectedWalletId;
  final String? selectedMainCategoryId;
  final String? selectedType;
  final bool? onlyTaxDeductible;
  final String searchQuery;

  TransactionFilters({
    required this.selectedMonth,
    this.selectedWalletId,
    this.selectedMainCategoryId,
    this.selectedType,
    this.onlyTaxDeductible,
    this.searchQuery = '',
  });

  TransactionFilters copyWith({
    DateTime? selectedMonth,
    String? selectedWalletId,
    String? selectedMainCategoryId,
    String? selectedType,
    bool? onlyTaxDeductible,
    String? searchQuery,
  }) {
    return TransactionFilters(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedWalletId: selectedWalletId,
      selectedMainCategoryId: selectedMainCategoryId,
      selectedType: selectedType,
      onlyTaxDeductible: onlyTaxDeductible,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final transactionFiltersProvider =
    StateNotifierProvider<TransactionFiltersNotifier, TransactionFilters>((ref) {
  return TransactionFiltersNotifier();
});

class TransactionFiltersNotifier extends StateNotifier<TransactionFilters> {
  TransactionFiltersNotifier()
      : super(TransactionFilters(selectedMonth: DateTime.now()));

  void setMonth(DateTime date) => state = state.copyWith(selectedMonth: date);
  void nextMonth() {
    final next = DateTime(state.selectedMonth.year, state.selectedMonth.month + 1);
    state = state.copyWith(selectedMonth: next);
  }
  void previousMonth() {
    final prev = DateTime(state.selectedMonth.year, state.selectedMonth.month - 1);
    state = state.copyWith(selectedMonth: prev);
  }
  void setWallet(String? walletId) {
    state = TransactionFilters(
      selectedMonth: state.selectedMonth,
      selectedWalletId: walletId,
      selectedMainCategoryId: state.selectedMainCategoryId,
      selectedType: state.selectedType,
      onlyTaxDeductible: state.onlyTaxDeductible,
      searchQuery: state.searchQuery,
    );
  }
  void setMainCategory(String? categoryId) {
    state = TransactionFilters(
      selectedMonth: state.selectedMonth,
      selectedWalletId: state.selectedWalletId,
      selectedMainCategoryId: categoryId,
      selectedType: state.selectedType,
      onlyTaxDeductible: state.onlyTaxDeductible,
      searchQuery: state.searchQuery,
    );
  }
  void setType(String? type) {
    state = TransactionFilters(
      selectedMonth: state.selectedMonth,
      selectedWalletId: state.selectedWalletId,
      selectedMainCategoryId: state.selectedMainCategoryId,
      selectedType: type,
      onlyTaxDeductible: state.onlyTaxDeductible,
      searchQuery: state.searchQuery,
    );
  }
  void toggleTaxDeductible(bool? val) {
    state = TransactionFilters(
      selectedMonth: state.selectedMonth,
      selectedWalletId: state.selectedWalletId,
      selectedMainCategoryId: state.selectedMainCategoryId,
      selectedType: state.selectedType,
      onlyTaxDeductible: val,
      searchQuery: state.searchQuery,
    );
  }
  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);
  void resetFilters() => state = TransactionFilters(selectedMonth: DateTime.now());
}

final filteredTransactionsProvider = Provider<List<TransactionItem>>((ref) {
  final transactions = ref.watch(rawTransactionsProvider);
  final filters = ref.watch(transactionFiltersProvider);

  return transactions.where((tx) {
    if (tx.date.year != filters.selectedMonth.year ||
        tx.date.month != filters.selectedMonth.month) return false;
    if (filters.selectedWalletId != null && tx.walletId != filters.selectedWalletId) return false;
    if (filters.selectedMainCategoryId != null &&
        tx.mainCategoryId != filters.selectedMainCategoryId) return false;
    if (filters.selectedType != null && tx.type != filters.selectedType) return false;
    if (filters.onlyTaxDeductible == true && !tx.isTaxDeductible) return false;
    if (filters.searchQuery.isNotEmpty) {
      final query = filters.searchQuery.toLowerCase();
      final noteMatch = tx.note?.toLowerCase().contains(query) ?? false;
      final amountMatch = tx.amount.toString().contains(query);
      if (!noteMatch && !amountMatch) return false;
    }
    return true;
  }).toList();
});

class RawTransactionsNotifier extends StateNotifier<List<TransactionItem>> {
  final TransactionRepository _repository;
  final String? _roomId;
  StreamSubscription<List<TransactionItem>>? _subscription;

  RawTransactionsNotifier(this._repository, this._roomId) : super([]) {
    _init();
  }

  void _init() {
    if (_roomId == null) return;
    _subscription = _repository.watchTransactions(_roomId!).listen((list) {
      state = list;
    });
  }

  Future<void> loadTransactions() async {
    // No-op: transactions are synced automatically via real-time stream subscription
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> addTransaction(TransactionItem transaction,
      {File? receiptFile, StorageRepository? storageRepo}) async {
    if (_roomId == null) return;
    var finalTx = transaction;
    if (receiptFile != null && storageRepo != null) {
      try {
        final downloadUrl =
            await storageRepo.uploadReceiptImage(_roomId, transaction.id, receiptFile);
        finalTx = transaction.copyWith(receiptImageUrl: downloadUrl);
      } catch (_) {}
    }
    await _repository.saveTransaction(_roomId, finalTx);
  }

  Future<void> updateTransaction(TransactionItem transaction,
      {File? receiptFile, StorageRepository? storageRepo}) async {
    if (_roomId == null) return;
    var finalTx = transaction;
    if (receiptFile != null && storageRepo != null) {
      try {
        final downloadUrl =
            await storageRepo.uploadReceiptImage(_roomId, transaction.id, receiptFile);
        finalTx = transaction.copyWith(receiptImageUrl: downloadUrl);
      } catch (_) {}
    }
    await _repository.saveTransaction(_roomId, finalTx);
  }

  Future<void> deleteTransaction(String transactionId) async {
    if (_roomId == null) return;
    await _repository.deleteTransaction(_roomId, transactionId);
  }

  Future<void> updateCreatorNameForUser(String userId, String newName) async {
    if (_roomId == null) return;
    await _repository.updateCreatorNameForUser(_roomId, userId, newName);
  }
}
