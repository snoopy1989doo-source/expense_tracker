import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionItem {
  final String id;
  final String type; // 'income' | 'expense'
  final double amount;
  final DateTime date;
  final String mainCategoryId;
  final String subCategoryId;
  final String walletId;
  final String? note;
  final String? loveNote;
  final String? receiptImageUrl;
  final bool isTaxDeductible;
  final String? createdByUserId;
  final String? createdByName;
  final String? createdByPhoto;
  final DateTime createdAt;
  final DateTime updatedAt;

  TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.mainCategoryId,
    required this.subCategoryId,
    required this.walletId,
    this.note,
    this.loveNote,
    this.receiptImageUrl,
    required this.isTaxDeductible,
    this.createdByUserId,
    this.createdByName,
    this.createdByPhoto,
    required this.createdAt,
    required this.updatedAt,
  });

  TransactionItem copyWith({
    String? id,
    String? type,
    double? amount,
    DateTime? date,
    String? mainCategoryId,
    String? subCategoryId,
    String? walletId,
    String? note,
    String? loveNote,
    String? receiptImageUrl,
    bool? isTaxDeductible,
    String? createdByUserId,
    String? createdByName,
    String? createdByPhoto,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      mainCategoryId: mainCategoryId ?? this.mainCategoryId,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      walletId: walletId ?? this.walletId,
      note: note ?? this.note,
      loveNote: loveNote ?? this.loveNote,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      isTaxDeductible: isTaxDeductible ?? this.isTaxDeductible,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdByName: createdByName ?? this.createdByName,
      createdByPhoto: createdByPhoto ?? this.createdByPhoto,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'mainCategoryId': mainCategoryId,
      'subCategoryId': subCategoryId,
      'walletId': walletId,
      'note': note,
      'loveNote': loveNote,
      'receiptImageUrl': receiptImageUrl,
      'isTaxDeductible': isTaxDeductible,
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'createdByPhoto': createdByPhoto,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'date': date.toIso8601String(),
      'mainCategoryId': mainCategoryId,
      'subCategoryId': subCategoryId,
      'walletId': walletId,
      'note': note,
      'loveNote': loveNote,
      'receiptImageUrl': receiptImageUrl,
      'isTaxDeductible': isTaxDeductible,
      'createdByUserId': createdByUserId,
      'createdByName': createdByName,
      'createdByPhoto': createdByPhoto,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'] ?? value['secondsSinceEpoch'];
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch((seconds as num).toInt() * 1000);
      }
    }
    return DateTime.now();
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map, String docId) {
    return TransactionItem(
      id: docId,
      type: map['type'] ?? 'expense',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: _parseDateTime(map['date']),
      mainCategoryId: map['mainCategoryId'] ?? '',
      subCategoryId: map['subCategoryId'] ?? '',
      walletId: map['walletId'] ?? '',
      note: map['note'],
      loveNote: map['loveNote'] as String?,
      receiptImageUrl: map['receiptImageUrl'],
      isTaxDeductible: map['isTaxDeductible'] ?? false,
      createdByUserId: map['createdByUserId'] as String?,
      createdByName: map['createdByName'] as String?,
      createdByPhoto: map['createdByPhoto'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }
}
