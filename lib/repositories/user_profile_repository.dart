import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class UserProfileRepository {
  final FirebaseFirestore? _firestore;

  UserProfileRepository(this._firestore);

  bool get _isAvailable => _firestore != null;

  /// Stream of user profile (real-time updates)
  Stream<UserProfile?> watchUserProfile(String userId) {
    if (!_isAvailable) return Stream.value(null);
    return _firestore!
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserProfile.fromMap(snap.data()!, snap.id);
    });
  }

  /// Create or update a user profile
  Future<void> saveProfile(UserProfile profile) async {
    if (!_isAvailable) return;
    await _firestore!
        .collection('users')
        .doc(profile.id)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  /// Update only coupleRoomId
  Future<void> setCoupleRoomId(String userId, String coupleRoomId) async {
    if (!_isAvailable) return;
    await _firestore!
        .collection('users')
        .doc(userId)
        .update({'coupleRoomId': coupleRoomId});
  }

  /// Get a user profile once (not streaming)
  Future<UserProfile?> getUserProfile(String userId) async {
    if (!_isAvailable) return null;
    final doc = await _firestore!.collection('users').doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromMap(doc.data()!, doc.id);
  }
}
