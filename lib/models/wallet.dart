import 'package:cloud_firestore/cloud_firestore.dart';

class Wallet {
  final String id;
  final String name;
  final String color;
  final String icon;
  final double startingBalance;
  final double currentBalance; // Dynamic calculated or reconciled
  final int order;
  final DateTime createdAt;

  Wallet({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.startingBalance,
    required this.currentBalance,
    required this.order,
    required this.createdAt,
  });

  Wallet copyWith({
    String? id,
    String? name,
    String? color,
    String? icon,
    double? startingBalance,
    double? currentBalance,
    int? order,
    DateTime? createdAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      startingBalance: startingBalance ?? this.startingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'icon': icon,
      'startingBalance': startingBalance,
      'currentBalance': currentBalance,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Wallet.fromMap(Map<String, dynamic> map, String docId) {
    return Wallet(
      id: docId,
      name: map['name'] ?? '',
      color: map['color'] ?? '#1E88E5',
      icon: map['icon'] ?? 'account_balance_wallet',
      startingBalance: (map['startingBalance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['currentBalance'] as num?)?.toDouble() ?? 0.0,
      order: map['order'] ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
