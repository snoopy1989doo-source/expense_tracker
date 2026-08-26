import '../models/transaction_item.dart';
import '../models/main_category.dart';
import '../core/utils/currency_formatter.dart';

class AIPredictionResult {
  final String title;
  final String description;
  final double estimatedAmount;
  final String iconEmoji;
  final String urgency; // 'normal' | 'warning' | 'urgent'

  AIPredictionResult({
    required this.title,
    required this.description,
    required this.estimatedAmount,
    required this.iconEmoji,
    this.urgency = 'normal',
  });
}

class AIFinanceService {
  /// AI Finance Assistant Chat Engine
  static String answerUserQuery({
    required String query,
    required List<TransactionItem> transactions,
    required List<MainCategory> categories,
    required String? currentUserName,
  }) {
    final cleanQuery = query.toLowerCase().trim();
    final now = DateTime.now();

    // Current month transactions
    final currentMonthTxs = transactions.where((t) {
      return t.date.year == now.year && t.date.month == now.month;
    }).toList();

    final expenses = currentMonthTxs.where((t) => t.type == 'expense').toList();
    final income = currentMonthTxs.where((t) => t.type == 'income').toList();

    final totalExpense = expenses.fold(0.0, (sum, t) => sum + t.amount);
    final totalIncome = income.fold(0.0, (sum, t) => sum + t.amount);
    final netBalance = totalIncome - totalExpense;

    final catMap = {for (var c in categories) c.id: c.name};

    // 1. Query: Total expenses / Summary
    if (cleanQuery.contains('เท่าไหร่') || cleanQuery.contains('สรุป') || cleanQuery.contains('เดือนนี้')) {
      if (expenses.isEmpty) {
        return '💕 ในเดือนนี้คู่ของคุณยังไม่มีบันทึกรายจ่ายเข้ามาเลยครับ เริ่มต้นจดบันทึกเพื่อติดตามงบด้วยกันได้เลย!';
      }
      return '📊 **สรุปการเงินคู่รักประจำเดือนนี้:**\n\n'
          '• 💰 **รายรับรวม:** ${CurrencyFormatter.format(totalIncome)}\n'
          '• 💸 **รายจ่ายรวม:** ${CurrencyFormatter.format(totalExpense)}\n'
          '• ⚖️ **คงเหลือสุทธิ:** ${CurrencyFormatter.format(netBalance)}\n\n'
          '${netBalance >= 0 ? "เก่งมากครับ! เดือนนี้คุมงบได้ดีเยี่ยม มีเงินเหลือออมด้วยนะ 💕" : "เดือนนี้รายจ่ายค่อนข้างสูง ลองช่วยกันคุมงบมื้อเย็นเพิ่มเติมดูนะครับ ✌️"}';
    }

    // 2. Query: Who spent more (Partner Comparison)
    if (cleanQuery.contains('ใคร') || cleanQuery.contains('เทียบ') || cleanQuery.contains('จ่ายเยอะ')) {
      final Map<String, double> partnerExpense = {};
      for (var t in expenses) {
        final name = (t.createdByName != null && t.createdByName!.isNotEmpty)
            ? t.createdByName!
            : 'สมาชิกคู่รัก';
        partnerExpense[name] = (partnerExpense[name] ?? 0) + t.amount;
      }

      if (partnerExpense.isEmpty) {
        return 'ยังไม่มีข้อมูลการจ่ายเงินของเดือนนี้ครับ';
      }

      final sorted = partnerExpense.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final buffer = StringBuffer('👩‍❤️‍👨 **สถิติเปรียบเทียบการจ่ายเงินของคู่เรา:**\n\n');
      for (var entry in sorted) {
        final pct = totalExpense > 0 ? (entry.value / totalExpense * 100).toStringAsFixed(1) : '0';
        buffer.write('• **${entry.key}:** ${CurrencyFormatter.format(entry.value)} ($pct%)\n');
      }
      return buffer.toString();
    }

    // 3. Query: Food / Utility bills
    if (cleanQuery.contains('อาหาร') || cleanQuery.contains('กิน') || cleanQuery.contains('ไฟ') || cleanQuery.contains('น้ำ')) {
      final foodTxs = expenses.where((t) {
        final catName = catMap[t.mainCategoryId] ?? '';
        final note = (t.note ?? '').toLowerCase();
        return catName.contains('อาหาร') || catName.contains('กิน') || note.contains('ข้าว') || note.contains('ไฟ') || note.contains('น้ำ');
      }).toList();

      final foodTotal = foodTxs.fold(0.0, (sum, t) => sum + t.amount);
      return '🍚 **สรุปค่าหมวดหมู่ประจำเดือน:**\n'
          'ในเดือนนี้มียอดในหมวดหมู่นี้รวม **${CurrencyFormatter.format(foodTotal)}** (${foodTxs.length} รายการ)\n\n'
          '💡 AI แนะนำ: คุณสามารถวางแผนมื้ออาหารทำกินเองที่บ้านคู่กันเพื่อประหยัดงบได้เพิ่มอีก 15-20% เลยนะ!';
    }

    // Default friendly response
    return '🤖 **สวัสดีครับ! ผมคือ AI ที่ปรึกษาการเงินคู่รักของคุณ**\n\n'
        'เดือนนี้คู่ของคุณใช้จ่ายรวม **${CurrencyFormatter.format(totalExpense)}** '
        'คุณสามารถถามผมเพิ่มเติมได้ เช่น:\n'
        '• *"เดือนนี้เราใช้เงินไปเท่าไหร่?"*\n'
        '• *"ใครจ่ายเงินมากกว่ากันในเดือนนี้?"*\n'
        '• *"ทำนายบิลล่วงหน้า"*';
  }

  /// AI Expense Predictor Engine
  static List<AIPredictionResult> predictUpcomingExpenses(List<TransactionItem> transactions) {
    final predictions = <AIPredictionResult>[];
    final now = DateTime.now();

    final expenses = transactions.where((t) => t.type == 'expense').toList();
    if (expenses.isEmpty) {
      predictions.add(AIPredictionResult(
        title: 'เริ่มต้นการออมคู่รัก',
        description: 'ยังไม่มีข้อมูลบิลในอดีต เริ่มบันทึกสลิปค่าน้ำ/ค่าไฟเพื่อให้อ่านข้อมูลทำนายล่วงหน้า',
        estimatedAmount: 0,
        iconEmoji: '🌱',
      ));
      return predictions;
    }

    // Check electricity bills
    final elecTxs = expenses.where((t) {
      final note = (t.note ?? '').toLowerCase();
      return note.contains('ไฟ') || note.contains('pea') || note.contains('electric');
    }).toList();

    if (elecTxs.isNotEmpty) {
      final avgElec = elecTxs.fold(0.0, (sum, t) => sum + t.amount) / elecTxs.length;
      predictions.add(AIPredictionResult(
        title: 'บิลค่าไฟฟ้า (PEA)',
        description: 'คาดการณ์บิลค่าไฟฟ้าประจำเดือนประมาณ ${CurrencyFormatter.format(avgElec)} อย่าลืมสำรองเงินไว้นะครับ',
        estimatedAmount: avgElec,
        iconEmoji: '⚡',
        urgency: 'warning',
      ));
    } else {
      predictions.add(AIPredictionResult(
        title: 'คาดการณ์บิลค่าไฟ (PEA)',
        description: 'คาดการณ์บิลค่าไฟช่วงสิ้นเดือนประมาณ ฿350.00 บาท',
        estimatedAmount: 350.0,
        iconEmoji: '⚡',
      ));
    }

    // Check food ratio warning
    final currentMonthExpenses = expenses.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
    final monthTotal = currentMonthExpenses.fold(0.0, (sum, t) => sum + t.amount);

    if (monthTotal > 5000) {
      predictions.add(AIPredictionResult(
        title: 'เตือนงบประมาณรายจ่าย',
        description: 'เดือนนี้ยอดรวมรายจ่ายถึง ${CurrencyFormatter.format(monthTotal)} แล้ว แนะนำช่วยกันคุมงบปลายเดือน',
        estimatedAmount: monthTotal,
        iconEmoji: '🚨',
        urgency: 'urgent',
      ));
    } else {
      predictions.add(AIPredictionResult(
        title: 'สถานะงบประมาณคู่รัก',
        description: 'ขณะนี้การคุมงบการเงินของคู่เราอยู่ในเกณฑ์ดีเยี่ยม 💕',
        estimatedAmount: monthTotal,
        iconEmoji: '💕',
      ));
    }

    return predictions;
  }
}
