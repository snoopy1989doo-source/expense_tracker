class CoupleRoom {
  final String id;
  final String inviteCode;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;
  final List<Map<String, String>> customFoodMenu;
  final List<Map<String, String>> customQuests;

  CoupleRoom({
    required this.id,
    required this.inviteCode,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
    this.customFoodMenu = const [],
    this.customQuests = const [],
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
      customFoodMenu: (map['customFoodMenu'] as List? ?? [])
          .map((item) => Map<String, String>.from(item as Map))
          .toList(),
      customQuests: (map['customQuests'] as List? ?? [])
          .map((item) => Map<String, String>.from(item as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'inviteCode': inviteCode,
      'memberIds': memberIds,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'customFoodMenu': customFoodMenu,
      'customQuests': customQuests,
    };
  }
}
