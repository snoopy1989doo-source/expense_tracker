import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../repositories/couple_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../models/couple_room.dart';

// ─── Couple Repository Provider ───────────────────────────────────────────────

final coupleRepositoryProvider = Provider<CoupleRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return CoupleRepository(firestore);
});

// ─── Couple Room ID Provider ──────────────────────────────────────────────────

/// Returns the current user's coupleRoomId, or null if not in a couple yet
final coupleRoomIdProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider).value?.coupleRoomId;
});

// ─── Couple Room Stream ────────────────────────────────────────────────────────

final coupleRoomProvider = StreamProvider<CoupleRoom?>((ref) {
  final roomId = ref.watch(coupleRoomIdProvider);
  if (roomId == null) return Stream.value(null);
  final repo = ref.watch(coupleRepositoryProvider);
  return repo.watchCoupleRoom(roomId);
});

// ─── Couple Notifier (for setup actions) ─────────────────────────────────────

final coupleNotifierProvider =
    StateNotifierProvider<CoupleNotifier, CoupleState>((ref) {
  final coupleRepo = ref.watch(coupleRepositoryProvider);
  final profileRepo = ref.watch(userProfileRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  return CoupleNotifier(coupleRepo, profileRepo, authState.value);
});

class CoupleState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final String? inviteCode; // Code shown after creating a room

  const CoupleState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.inviteCode,
  });

  CoupleState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    String? inviteCode,
  }) {
    return CoupleState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }
}

class CoupleNotifier extends StateNotifier<CoupleState> {
  final CoupleRepository _coupleRepo;
  final UserProfileRepository _profileRepo;
  final String? _userId;

  CoupleNotifier(this._coupleRepo, this._profileRepo, this._userId)
      : super(const CoupleState());

  /// Create a new couple room and show the invite code
  Future<void> createRoom() async {
    if (_userId == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final room = await _coupleRepo.createCoupleRoom(_userId);
      // Update user profile with the new room ID
      await _profileRepo.setCoupleRoomId(_userId, room.id);
      state = state.copyWith(
        isLoading: false,
        inviteCode: room.inviteCode,
        successMessage: 'สร้างห้องสำเร็จ! แชร์โค้ดด้านล่างให้แฟนของคุณ',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Join an existing couple room using an invite code
  Future<bool> joinRoom(String inviteCode) async {
    if (_userId == null) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final room = await _coupleRepo.joinCoupleRoom(inviteCode, _userId);
      // Update user profile with the joined room ID
      await _profileRepo.setCoupleRoomId(_userId, room.id);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'เข้าร่วมห้องสำเร็จ! 💕',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }
}
