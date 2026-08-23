class SubCategory {
  final String id;
  final String mainCategoryId;
  final String name;
  final String emoji;
  final String color; // Inherited from MainCategory, read-only from UI
  final int order;

  SubCategory({
    required this.id,
    required this.mainCategoryId,
    required this.name,
    required this.emoji,
    required this.color,
    required this.order,
  });

  SubCategory copyWith({
    String? id,
    String? mainCategoryId,
    String? name,
    String? emoji,
    String? color,
    int? order,
  }) {
    return SubCategory(
      id: id ?? this.id,
      mainCategoryId: mainCategoryId ?? this.mainCategoryId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mainCategoryId': mainCategoryId,
      'name': name,
      'emoji': emoji,
      'color': color,
      'order': order,
    };
  }

  factory SubCategory.fromMap(Map<String, dynamic> map, String docId) {
    return SubCategory(
      id: docId,
      mainCategoryId: map['mainCategoryId'] ?? '',
      name: map['name'] ?? '',
      emoji: map['emoji'] ?? '📄',
      color: map['color'] ?? '#1E88E5',
      order: map['order'] ?? 0,
    );
  }
}
