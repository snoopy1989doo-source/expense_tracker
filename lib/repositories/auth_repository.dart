import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthRepository {
  Stream<String?> get authStateChanges;
  String? get currentUserId;
  Future<String?> signInWithEmailAndPassword(String email, String password);
  Future<String?> signUpWithEmailAndPassword(String email, String password);
  Future<void> signOut();
  Future<void> loginAsGuest();
}

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final SharedPreferences _prefs;
  bool _useLocalMock = false;

  FirebaseAuthRepository(this._firebaseAuth, this._prefs) {
    // Check if Firebase is initialized and working, or if we should default to mock
    try {
      // Just a quick check to see if firebase auth works
      _firebaseAuth.app;
    } catch (_) {
      _useLocalMock = true;
    }
  }

  @override
  Stream<String?> get authStateChanges {
    if (_useLocalMock) {
      // Simple mock auth stream based on shared preferences
      return Stream.value(_prefs.getString('mock_userId'));
    }
    return _firebaseAuth.authStateChanges().map((user) => user?.uid);
  }

  @override
  String? get currentUserId {
    if (_useLocalMock) {
      return _prefs.getString('mock_userId');
    }
    return _firebaseAuth.currentUser?.uid;
  }

  @override
  Future<String?> signInWithEmailAndPassword(String email, String password) async {
    if (_useLocalMock) {
      if (email.contains('@') && password.length >= 6) {
        final mockId = 'mock_user_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
        await _prefs.setString('mock_userId', mockId);
        return mockId;
      }
      throw Exception('อีเมลหรือรหัสผ่านไม่ถูกต้อง (ขั้นต่ำ 6 ตัวอักษร)');
    }
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user?.uid;
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_translateFirebaseError(e.code));
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: ${e.toString()}');
    }
  }

  @override
  Future<String?> signUpWithEmailAndPassword(String email, String password) async {
    if (_useLocalMock) {
      if (email.contains('@') && password.length >= 6) {
        final mockId = 'mock_user_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
        await _prefs.setString('mock_userId', mockId);
        return mockId;
      }
      throw Exception('สมัครสมาชิกไม่สำเร็จ: อีเมลไม่ถูกต้องหรือรหัสผ่านสั้นเกินไป');
    }
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user?.uid;
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_translateFirebaseError(e.code));
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    if (_useLocalMock) {
      await _prefs.remove('mock_userId');
      return;
    }
    await _firebaseAuth.signOut();
  }

  @override
  Future<void> loginAsGuest() async {
    if (_useLocalMock) {
      await _prefs.setString('mock_userId', 'guest_user');
      return;
    }
    try {
      final credential = await _firebaseAuth.signInAnonymously();
      // Tag it in prefs too
      await _prefs.setString('mock_userId', credential.user?.uid ?? 'guest_user');
    } catch (e) {
      // Fallback to local mock guest if sign in anonymously fails
      await _prefs.setString('mock_userId', 'guest_user');
    }
  }

  String _translateFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'ไม่พบบัญชีผู้ใช้นี้ในระบบ';
      case 'wrong-password':
        return 'รหัสผ่านไม่ถูกต้อง';
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้งานแล้วในระบบ';
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'weak-password':
        return 'รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร';
      case 'operation-not-allowed':
        return 'การเข้าสู่ระบบแบบไม่เปิดเผยตัวตนยังไม่เปิดใช้งาน';
      default:
        return 'เกิดข้อผิดพลาดเกี่ยวกับระบบสมาชิก ($code)';
    }
  }
}
