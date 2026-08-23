class LiabilityItem {
  final String id;
  final String name;
  final String type; // 'loan' | 'credit_card' | 'informal' | 'other'
  final double totalAmount;
  final double remainingAmount;
  final double? interestRate;
  final double? monthlyPayment;

  LiabilityItem({
    required this.id,
    required this.name,
    required this.type,
    required this.totalAmount,
    required this.remainingAmount,
    this.interestRate,
    this.monthlyPayment,
  });

  LiabilityItem copyWith({
    String? id,
    String? name,
    String? type,
    double? totalAmount,
    double? remainingAmount,
    double? interestRate,
    double? monthlyPayment,
  }) {
    return LiabilityItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      totalAmount: totalAmount ?? this.totalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      interestRate: interestRate ?? this.interestRate,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'totalAmount': totalAmount,
      'remainingAmount': remainingAmount,
      'interestRate': interestRate,
      'monthlyPayment': monthlyPayment,
    };
  }

  factory LiabilityItem.fromMap(Map<String, dynamic> map, String docId) {
    return LiabilityItem(
      id: docId,
      name: map['name'] ?? '',
      type: map['type'] ?? 'other',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (map['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      interestRate: (map['interestRate'] as num?)?.toDouble(),
      monthlyPayment: (map['monthlyPayment'] as num?)?.toDouble(),
    );
  }
}
