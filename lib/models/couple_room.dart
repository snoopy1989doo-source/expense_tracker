class CoupleRoom {
  final String id;
  final String inviteCode;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;

  CoupleRoom({
    required this.id,
    required this.inviteCode,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isFull => memberIds.length >= 2;

  factory CoupleRoom.fromMap(Map<String, dynamic> map, String id) {
    return CoupleRoom(
      id: id,
      inviteCode: map['inviteCode'] as String? ?? '',
      memberIds: List<String>.from(map['memberIds'] as List? ?? []),
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'inviteCode': inviteCode,
      'memberIds': memberIds,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
