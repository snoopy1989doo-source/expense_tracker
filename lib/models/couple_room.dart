class CoupleRoom {
  final String id;
  final String inviteCode;
  final List<String> memberIds;
  final String createdBy;
  final DateTime createdAt;
  final List<Map<String, String>> customFoodMenu;
  final List<Map<String, String>> customQuests;
  final Map<String, double> subcategoryBudgets; // {subCatId: monthlyBudgetAmount}
  final List<String> deletedDefaultFood;
  final List<String> deletedDefaultQuests;

  CoupleRoom({
    required this.id,
    required this.inviteCode,
    required this.memberIds,
    required this.createdBy,
    required this.createdAt,
    this.customFoodMenu = const [],
    this.customQuests = const [],
    this.subcategoryBudgets = const {},
    this.deletedDefaultFood = const [],
    this.deletedDefaultQuests = const [],
  });

  bool get isFull => memberIds.length >= 2;

  factory CoupleRoom.fromMap(Map<String, dynamic> map, String id) {
    // Parse subcategory budgets
    final rawBudgets = map['subcategoryBudgets'] as Map? ?? {};
    final Map<String, double> budgets = {};
    rawBudgets.forEach((k, v) {
      if (v != null) {
        budgets[k.toString()] = (v is num) ? v.toDouble() : (double.tryParse(v.toString()) ?? 0.0);
      }
    });

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
      subcategoryBudgets: budgets,
      deletedDefaultFood: List<String>.from(map['deletedDefaultFood'] as List? ?? []),
      deletedDefaultQuests: List<String>.from(map['deletedDefaultQuests'] as List? ?? []),
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
      'subcategoryBudgets': subcategoryBudgets,
      'deletedDefaultFood': deletedDefaultFood,
      'deletedDefaultQuests': deletedDefaultQuests,
    };
  }
}
