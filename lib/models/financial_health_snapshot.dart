class FinancialHealthSnapshot {
  final String id;
  final String month; // YYYY-MM
  final double netWorth;
  final double savingsRate;
  final double debtToIncomeRatio;
  final double score;

  FinancialHealthSnapshot({
    required this.id,
    required this.month,
    required this.netWorth,
    required this.savingsRate,
    required this.debtToIncomeRatio,
    required this.score,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'month': month,
      'netWorth': netWorth,
      'savingsRate': savingsRate,
      'debtToIncomeRatio': debtToIncomeRatio,
      'score': score,
    };
  }

  factory FinancialHealthSnapshot.fromMap(Map<String, dynamic> map, String docId) {
    return FinancialHealthSnapshot(
      id: docId,
      month: map['month'] ?? '',
      netWorth: (map['netWorth'] as num?)?.toDouble() ?? 0.0,
      savingsRate: (map['savingsRate'] as num?)?.toDouble() ?? 0.0,
      debtToIncomeRatio: (map['debtToIncomeRatio'] as num?)?.toDouble() ?? 0.0,
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
