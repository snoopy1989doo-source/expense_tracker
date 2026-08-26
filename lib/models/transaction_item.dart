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

  factory TransactionItem.fromMap(Map<String, dynamic> map, String docId) {
    return TransactionItem(
      id: docId,
      type: map['type'] ?? 'expense',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] != null
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
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
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
