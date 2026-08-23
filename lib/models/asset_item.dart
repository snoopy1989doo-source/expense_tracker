import 'package:cloud_firestore/cloud_firestore.dart';

class AssetItem {
  final String id;
  final String name;
  final String category; // 'cash' | 'investment' | 'property' | 'vehicle' | 'other'
  final double value;
  final DateTime lastUpdated;

  AssetItem({
    required this.id,
    required this.name,
    required this.category,
    required this.value,
    required this.lastUpdated,
  });

  AssetItem copyWith({
    String? id,
    String? name,
    String? category,
    double? value,
    DateTime? lastUpdated,
  }) {
    return AssetItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      value: value ?? this.value,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'value': value,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory AssetItem.fromMap(Map<String, dynamic> map, String docId) {
    return AssetItem(
      id: docId,
      name: map['name'] ?? '',
      category: map['category'] ?? 'other',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
