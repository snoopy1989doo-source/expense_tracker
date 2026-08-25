class UserProfile {
  final String id;
  final String email;
  final String nickname;
  final String? photoBase64; // base64 image or Google photo URL
  final String? coupleRoomId;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    this.photoBase64,
    this.coupleRoomId,
    required this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String id) {
    return UserProfile(
      id: id,
      email: map['email'] as String? ?? '',
      nickname: map['nickname'] as String? ?? '',
      photoBase64: map['photoBase64'] as String?,
      coupleRoomId: map['coupleRoomId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nickname': nickname,
      'photoBase64': photoBase64,
      'coupleRoomId': coupleRoomId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  UserProfile copyWith({
    String? email,
    String? nickname,
    String? photoBase64,
    String? coupleRoomId,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      photoBase64: photoBase64 ?? this.photoBase64,
      coupleRoomId: coupleRoomId ?? this.coupleRoomId,
      createdAt: createdAt,
    );
  }
}
