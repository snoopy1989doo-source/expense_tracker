import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';
import 'auth_provider.dart';
import 'category_provider.dart';
import 'transaction_provider.dart';
import '../models/wallet.dart';
import '../repositories/wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirestoreWalletRepository(firestore, prefs);
});

// The source wallets stored in db
final rawWalletsProvider = StateNotifierProvider<RawWalletsNotifier, List<Wallet>>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final userId = authState.value;
  return RawWalletsNotifier(repository, userId);
});

// The wallets with real-time calculated balances based on startingBalance and transactions
final walletsProvider = Provider<List<Wallet>>((ref) {
  final rawWallets = ref.watch(rawWalletsProvider);
  final transactions = ref.watch(rawTransactionsProvider);

  return rawWallets.map((wallet) {
    double balance = wallet.startingBalance;
    
    // Filter transactions for this wallet
    final walletTransactions = transactions.where((tx) => tx.walletId == wallet.id);
    for (var tx in walletTransactions) {
      if (tx.type == 'income') {
        balance += tx.amount;
      } else if (tx.type == 'expense') {
        balance -= tx.amount;
      }
    }
    
    return wallet.copyWith(currentBalance: balance);
  }).toList();
});

class RawWalletsNotifier extends StateNotifier<List<Wallet>> {
  final WalletRepository _repository;
  final String? _userId;

  RawWalletsNotifier(this._repository, this._userId) : super([]) {
    loadWallets();
  }

  Future<void> loadWallets() async {
    if (_userId == null) return;
    try {
      final list = await _repository.getWallets(_userId);
      state = list;
    } catch (_) {}
  }

  Future<void> addWallet(Wallet wallet) async {
    if (_userId == null) return;
    await _repository.saveWallet(_userId, wallet);
    await loadWallets();
  }

  Future<void> updateWallet(Wallet wallet) async {
    if (_userId == null) return;
    await _repository.saveWallet(_userId, wallet);
    await loadWallets();
  }

  Future<void> deleteWallet(String walletId) async {
    if (_userId == null) return;
    await _repository.deleteWallet(_userId, walletId);
    await loadWallets();
  }

  Future<void> resetToDefault() async {
    if (_userId == null) return;
    await _repository.seedDefaultWallets(_userId);
    await loadWallets();
  }
}
