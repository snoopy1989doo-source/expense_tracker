import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'couple_provider.dart';
import 'transaction_provider.dart';
import '../models/wallet.dart';
import '../repositories/wallet_repository.dart';
import 'theme_provider.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirestoreWalletRepository(firestore, prefs);
});

final rawWalletsProvider =
    StateNotifierProvider<RawWalletsNotifier, List<Wallet>>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  final userId = authState.value;
  final coupleRoomId = ref.watch(coupleRoomIdProvider);
  final effectiveId = coupleRoomId ?? userId;
  return RawWalletsNotifier(repository, effectiveId);
});

final walletsProvider = Provider<List<Wallet>>((ref) {
  final rawWallets = ref.watch(rawWalletsProvider);
  final transactions = ref.watch(rawTransactionsProvider);

  return rawWallets.map((wallet) {
    double balance = wallet.startingBalance;
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
  final String? _roomId;

  RawWalletsNotifier(this._repository, this._roomId) : super([]) {
    loadWallets();
  }

  Future<void> loadWallets() async {
    if (_roomId == null) return;
    try {
      final list = await _repository.getWallets(_roomId);
      state = list;
    } catch (_) {}
  }

  Future<void> addWallet(Wallet wallet) async {
    if (_roomId == null) return;
    await _repository.saveWallet(_roomId, wallet);
    await loadWallets();
  }

  Future<void> updateWallet(Wallet wallet) async {
    if (_roomId == null) return;
    await _repository.saveWallet(_roomId, wallet);
    await loadWallets();
  }

  Future<void> deleteWallet(String walletId) async {
    if (_roomId == null) return;
    await _repository.deleteWallet(_roomId, walletId);
    await loadWallets();
  }

  Future<void> resetToDefault() async {
    if (_roomId == null) return;
    await _repository.seedDefaultWallets(_roomId);
    await loadWallets();
  }
}
