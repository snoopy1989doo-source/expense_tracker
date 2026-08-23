import 'package:cloud_firestore/cloud_firestore.dart';

class MainCategory {
  final String id;
  final String name;
  final String color;
  final String emoji;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  MainCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.emoji,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  MainCategory copyWith({
    String? id,
    String? name,
    String? color,
    String? emoji,
    int? order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MainCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'emoji': emoji,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory MainCategory.fromMap(Map<String, dynamic> map, String docId) {
    return MainCategory(
      id: docId,
      name: map['name'] ?? '',
      color: map['color'] ?? '#1E88E5',
      emoji: map['emoji'] ?? '📁',
      order: map['order'] ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
