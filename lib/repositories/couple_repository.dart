import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/couple_room.dart';

class CoupleRepository {
  final FirebaseFirestore? _firestore;

  CoupleRepository(this._firestore);

  bool get _isAvailable => _firestore != null;

  /// Generate a random 6-character uppercase invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No ambiguous chars
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Create a new couple room and return it
  Future<CoupleRoom> createCoupleRoom(String createdBy) async {
    if (!_isAvailable) throw Exception('Firebase ไม่พร้อมใช้งาน');

    final code = _generateInviteCode();
    final roomRef = _firestore!.collection('couple_rooms').doc();

    final room = CoupleRoom(
      id: roomRef.id,
      inviteCode: code,
      memberIds: [createdBy],
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    final batch = _firestore.batch();

    // Create room document
    batch.set(roomRef, room.toMap());

    // Store invite code → roomId mapping for fast lookup
    batch.set(
      _firestore.collection('invite_codes').doc(code),
      {
        'roomId': room.id,
        'createdBy': createdBy,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    );

    await batch.commit();
    return room;
  }

  /// Join an existing couple room via invite code
  Future<CoupleRoom> joinCoupleRoom(String inviteCode, String userId) async {
    if (!_isAvailable) throw Exception('Firebase ไม่พร้อมใช้งาน');

    // Look up invite code
    final codeDoc = await _firestore!
        .collection('invite_codes')
        .doc(inviteCode.toUpperCase())
        .get();

    if (!codeDoc.exists) throw Exception('ไม่พบโค้ดนี้ในระบบ กรุณาตรวจสอบอีกครั้ง');

    final roomId = codeDoc.data()!['roomId'] as String;

    // Get the room
    final roomDoc = await _firestore.collection('couple_rooms').doc(roomId).get();
    if (!roomDoc.exists) throw Exception('ไม่พบห้องคู่รัก กรุณาติดต่อผู้สร้างห้อง');

    final room = CoupleRoom.fromMap(roomDoc.data()!, roomDoc.id);

    if (room.isFull && !room.memberIds.contains(userId)) {
      throw Exception('ห้องนี้มีสมาชิกครบแล้ว (2 คน)');
    }

    if (!room.memberIds.contains(userId)) {
      // Add this user to the room
      await _firestore.collection('couple_rooms').doc(roomId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
      });
    }

    // Delete invite code after joining (one-time use)
    await _firestore.collection('invite_codes').doc(inviteCode.toUpperCase()).delete();

    // Return updated room
    final updatedDoc = await _firestore.collection('couple_rooms').doc(roomId).get();
    return CoupleRoom.fromMap(updatedDoc.data()!, updatedDoc.id);
  }

  /// Stream of couple room (real-time updates)
  Stream<CoupleRoom?> watchCoupleRoom(String roomId) {
    if (!_isAvailable) return Stream.value(null);
    return _firestore!
        .collection('couple_rooms')
        .doc(roomId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return CoupleRoom.fromMap(snap.data()!, snap.id);
    });
  }
}
