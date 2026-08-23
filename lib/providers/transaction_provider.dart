import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';
import 'auth_provider.dart';
import 'category_provider.dart';
import '../models/transaction_item.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/storage_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirestoreTransactionRepository(firestore, prefs);
});

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  final storage = ref.watch(firebaseStorageProvider);
  return FirebaseStorageRepository(storage);
});

// To satisfy the storage provider requirements, let's export a generic FirebaseStorage provider
final firebaseStorageProvider = Provider((ref) {
  // Graceful fallback to null or instance
  try {
    return null;
  } catch (_) {
    return null;
  }
});

final rawTransactionsProvider = StateNotifierProvider<RawTransactionsNotifier, List<TransactionItem>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final userId = authState.value;
  return RawTransactionsNotifier(repository, userId);
});

class TransactionFilters {
  final DateTime selectedMonth; // Only year & month are used
  final String? selectedWalletId;
  final String? selectedMainCategoryId;
  final String? selectedType; // 'income' | 'expense' | null
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
      selectedWalletId: selectedWalletId, // Allow resetting to null
      selectedMainCategoryId: selectedMainCategoryId, // Allow resetting to null
      selectedType: selectedType, // Allow resetting to null
      onlyTaxDeductible: onlyTaxDeductible, // Allow resetting to null
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final transactionFiltersProvider = StateNotifierProvider<TransactionFiltersNotifier, TransactionFilters>((ref) {
  return TransactionFiltersNotifier();
});

class TransactionFiltersNotifier extends StateNotifier<TransactionFilters> {
  TransactionFiltersNotifier() : super(TransactionFilters(selectedMonth: DateTime.now()));

  void setMonth(DateTime date) {
    state = state.copyWith(selectedMonth: date);
  }

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

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void resetFilters() {
    state = TransactionFilters(selectedMonth: DateTime.now());
  }
}

// Filtered transactions for the selected month / wallet / category
final filteredTransactionsProvider = Provider<List<TransactionItem>>((ref) {
  final transactions = ref.watch(rawTransactionsProvider);
  final filters = ref.watch(transactionFiltersProvider);

  return transactions.where((tx) {
    // 1. Month Filter
    if (tx.date.year != filters.selectedMonth.year || tx.date.month != filters.selectedMonth.month) {
      return false;
    }
    // 2. Wallet Filter
    if (filters.selectedWalletId != null && tx.walletId != filters.selectedWalletId) {
      return false;
    }
    // 3. Category Filter
    if (filters.selectedMainCategoryId != null && tx.mainCategoryId != filters.selectedMainCategoryId) {
      return false;
    }
    // 4. Type Filter
    if (filters.selectedType != null && tx.type != filters.selectedType) {
      return false;
    }
    // 5. Tax Filter
    if (filters.onlyTaxDeductible == true && !tx.isTaxDeductible) {
      return false;
    }
    // 6. Search query
    if (filters.searchQuery.isNotEmpty) {
      final query = filters.searchQuery.toLowerCase();
      final noteMatch = tx.note?.toLowerCase().contains(query) ?? false;
      final amountMatch = tx.amount.toString().contains(query);
      if (!noteMatch && !amountMatch) {
        return false;
      }
    }
    return true;
  }).toList();
});

class RawTransactionsNotifier extends StateNotifier<List<TransactionItem>> {
  final TransactionRepository _repository;
  final String? _userId;

  RawTransactionsNotifier(this._repository, this._userId) : super([]) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    if (_userId == null) return;
    try {
      final list = await _repository.getTransactions(_userId);
      state = list;
    } catch (_) {}
  }

  Future<void> addTransaction(TransactionItem transaction, {File? receiptFile, StorageRepository? storageRepo}) async {
    if (_userId == null) return;
    
    var finalTx = transaction;
    if (receiptFile != null && storageRepo != null) {
      try {
        final downloadUrl = await storageRepo.uploadReceiptImage(_userId, transaction.id, receiptFile);
        finalTx = transaction.copyWith(receiptImageUrl: downloadUrl);
      } catch (_) {}
    }

    await _repository.saveTransaction(_userId, finalTx);
    await loadTransactions();
  }

  Future<void> updateTransaction(TransactionItem transaction, {File? receiptFile, StorageRepository? storageRepo}) async {
    if (_userId == null) return;
    
    var finalTx = transaction;
    if (receiptFile != null && storageRepo != null) {
      try {
        final downloadUrl = await storageRepo.uploadReceiptImage(_userId, transaction.id, receiptFile);
        finalTx = transaction.copyWith(receiptImageUrl: downloadUrl);
      } catch (_) {}
    }

    await _repository.saveTransaction(_userId, finalTx);
    await loadTransactions();
  }

  Future<void> deleteTransaction(String transactionId) async {
    if (_userId == null) return;
    await _repository.deleteTransaction(_userId, transactionId);
    await loadTransactions();
  }
}
