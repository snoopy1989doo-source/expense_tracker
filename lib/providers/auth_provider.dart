import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';
import '../repositories/auth_repository.dart';

final firebaseAuthProvider = Provider<fb.FirebaseAuth?>((ref) {
  try {
    return Firebase.apps.isNotEmpty ? fb.FirebaseAuth.instance : null;
  } catch (_) {
    return null;
  }
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return FirebaseAuthRepository(firebaseAuth, prefs);
});

final authStateProvider = StreamProvider<String?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? errorMessage;

  AuthState({
    required this.status,
    this.userId,
    this.errorMessage,
  });

  factory AuthState.initial() => AuthState(status: AuthStatus.initial);
  factory AuthState.loading() => AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(String uid) => AuthState(status: AuthStatus.authenticated, userId: uid);
  factory AuthState.unauthenticated() => AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.error(String msg) => AuthState(status: AuthStatus.error, errorMessage: msg);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState.initial()) {
    _init();
  }

  void _init() {
    _repository.authStateChanges.listen((userId) {
      if (userId != null) {
        state = AuthState.authenticated(userId);
      } else {
        state = AuthState.unauthenticated();
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    state = AuthState.loading();
    try {
      final uid = await _repository.signInWithEmailAndPassword(email, password);
      if (uid != null) {
        state = AuthState.authenticated(uid);
      } else {
        state = AuthState.error('ไม่สามารถเข้าสู่ระบบได้');
      }
    } catch (e) {
      state = AuthState.error(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> signUp(String email, String password) async {
    state = AuthState.loading();
    try {
      final uid = await _repository.signUpWithEmailAndPassword(email, password);
      if (uid != null) {
        state = AuthState.authenticated(uid);
      } else {
        state = AuthState.error('ไม่สามารถสมัครสมาชิกได้');
      }
    } catch (e) {
      state = AuthState.error(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> loginAsGuest() async {
    state = AuthState.loading();
    try {
      await _repository.loginAsGuest();
      final uid = _repository.currentUserId;
      if (uid != null) {
        state = AuthState.authenticated(uid);
      } else {
        state = AuthState.error('ไม่สามารถเข้าสู่ระบบแบบเกสต์ได้');
      }
    } catch (e) {
      state = AuthState.error('เกิดข้อผิดพลาดในการเข้าสู่ระบบแบบเกสต์');
    }
  }

  Future<void> signOut() async {
    state = AuthState.loading();
    await _repository.signOut();
    state = AuthState.unauthenticated();
  }
}
