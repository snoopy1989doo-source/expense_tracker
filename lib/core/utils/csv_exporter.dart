import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/transaction_item.dart';
import '../../models/main_category.dart';
import '../../models/sub_category.dart';
import '../../models/wallet.dart';
import 'date_formatter.dart';

class CsvExporter {
  static String generateCsvString({
    required List<TransactionItem> transactions,
    required List<MainCategory> mainCategories,
    required List<SubCategory> subCategories,
    required List<Wallet> wallets,
  }) {
    final Map<String, MainCategory> mainCatMap = {for (var c in mainCategories) c.id: c};
    final Map<String, SubCategory> subCatMap = {for (var c in subCategories) c.id: c};
    final Map<String, Wallet> walletMap = {for (var w in wallets) w.id: w};

    List<List<dynamic>> rows = [];

    // Headers
    rows.add([
      'วันที่',
      'ประเภท',
      'หมวดหมู่หลัก',
      'หมวดหมู่ย่อย',
      'กระเป๋าเงิน',
      'จำนวนเงิน (บาท)',
      'ลดหย่อนภาษี',
      'บันทึกข้อความ',
      'ลิงก์ใบเสร็จ/หลักฐาน',
    ]);

    // Data rows
    for (var tx in transactions) {
      final mainCat = mainCatMap[tx.mainCategoryId]?.name ?? 'ไม่มีหมวดหมู่';
      final subCat = subCatMap[tx.subCategoryId]?.name ?? 'ไม่มีหมวดย่อย';
      final wallet = walletMap[tx.walletId]?.name ?? 'ไม่มีกระเป๋า';
      final taxStatus = tx.isTaxDeductible ? 'ใช่ (ลดหย่อนได้)' : 'ไม่ใช่';

      rows.add([
        DateFormatter.formatFullDateTime(tx.date),
        tx.type == 'income' ? 'รายรับ' : 'รายจ่าย',
        mainCat,
        subCat,
        wallet,
        tx.amount,
        taxStatus,
        tx.note ?? '',
        tx.receiptImageUrl ?? '',
      ]);
    }

    // Convert to CSV
    String csv = const ListToCsvConverter().convert(rows);
    // Add UTF-8 BOM so Excel opens Thai language correctly
    return '\uFEFF$csv';
  }

  static Future<File> saveCsvToFile(String csvContent, String filename) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename.csv');
    await file.writeAsString(csvContent, encoding: utf8);
    return file;
  }

  static Future<void> shareCsv({
    required List<TransactionItem> transactions,
    required List<MainCategory> mainCategories,
    required List<SubCategory> subCategories,
    required List<Wallet> wallets,
    required String filename,
  }) async {
    final csvContent = generateCsvString(
      transactions: transactions,
      mainCategories: mainCategories,
      subCategories: subCategories,
      wallets: wallets,
    );
    final file = await saveCsvToFile(csvContent, filename);
    
    // Share file
    final xFile = XFile(file.path);
    await Share.shareXFiles([xFile], text: 'รายงานสรุปรายรับ-รายจ่าย: $filename');
  }
}
