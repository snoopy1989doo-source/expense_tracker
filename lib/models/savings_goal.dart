class SavingsContribution {
  final String userId;
  final String userName;
  final double amount;
  final DateTime date;
  final String? note;

  SavingsContribution({
    required this.userId,
    required this.userName,
    required this.amount,
    required this.date,
    this.note,
  });

  factory SavingsContribution.fromMap(Map<String, dynamic> map) {
    return SavingsContribution(
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? 'สมาชิก',
      amount: (map['amount'] as num? ?? 0).toDouble(),
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date'] as int)
          : DateTime.now(),
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      if (note != null) 'note': note,
    };
  }
}

class SavingsGoal {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String emoji;
  final DateTime? targetDate;
  final List<SavingsContribution> contributions;
  final DateTime createdAt;

  SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0,
    this.emoji = '🐷',
    this.targetDate,
    this.contributions = const [],
    required this.createdAt,
  });

  double get progressPercentage =>
      targetAmount > 0 ? (currentAmount / targetAmount * 100).clamp(0, 100) : 0;

  bool get isCompleted => currentAmount >= targetAmount;

  factory SavingsGoal.fromMap(Map<String, dynamic> map, String id) {
    return SavingsGoal(
      id: id,
      title: map['title'] as String? ?? 'เป้าหมายออมเงิน',
      targetAmount: (map['targetAmount'] as num? ?? 0).toDouble(),
      currentAmount: (map['currentAmount'] as num? ?? 0).toDouble(),
      emoji: map['emoji'] as String? ?? '🐷',
      targetDate: map['targetDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['targetDate'] as int)
          : null,
      contributions: (map['contributions'] as List? ?? [])
          .map((item) => SavingsContribution.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'emoji': emoji,
      if (targetDate != null) 'targetDate': targetDate!.millisecondsSinceEpoch,
      'contributions': contributions.map((c) => c.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  SavingsGoal copyWith({
    String? title,
    double? targetAmount,
    double? currentAmount,
    String? emoji,
    DateTime? targetDate,
    List<SavingsContribution>? contributions,
  }) {
    return SavingsGoal(
      id: id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      emoji: emoji ?? this.emoji,
      targetDate: targetDate ?? this.targetDate,
      contributions: contributions ?? this.contributions,
      createdAt: createdAt,
    );
  }
}
