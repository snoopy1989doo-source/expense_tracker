import '../models/transaction_item.dart';
import '../models/main_category.dart';
import '../models/sub_category.dart';
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
  /// AI Finance Assistant Chat Engine (Deep Subcategories + Dynamic Learning)
  static String answerUserQuery({
    required String query,
    required List<TransactionItem> transactions,
    required List<MainCategory> categories,
    required List<SubCategory> subCategories,
    required Map<String, double> subcategoryBudgets,
    required String? currentUserName,
    String? partnerName,
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

    final mainCatMap = {for (var c in categories) c.id: c};
    final subCatMap = {for (var s in subCategories) s.id: s};

    // 0. Query: Subcategories Spending Breakdown (หมวดย่อย)
    if (cleanQuery.contains('ย่อย') || cleanQuery.contains('หมวดย่อย')) {
      if (expenses.isEmpty) {
        return '💕 ในเดือนนี้คู่ของคุณยังไม่มีบันทึกรายจ่ายเข้ามาเลยครับ เริ่มต้นจดบันทึกเพื่อติดตามงบด้วยกันได้เลย!';
      }

      final Map<String, double> subExpense = {};
      final Map<String, String> subEmojiMap = {};
      final Map<String, String> subParentMap = {};

      for (var t in expenses) {
        String subName;
        String emoji = '🏷️';
        String parentName = '';

        if (t.subCategoryId.isNotEmpty && subCatMap.containsKey(t.subCategoryId)) {
          final sub = subCatMap[t.subCategoryId]!;
          subName = sub.name;
          emoji = sub.emoji;
          final parent = mainCatMap[sub.mainCategoryId];
          if (parent != null) parentName = parent.name;
        } else if (t.note != null && t.note!.isNotEmpty) {
          subName = t.note!;
          emoji = '📝';
        } else {
          final main = mainCatMap[t.mainCategoryId];
          subName = main?.name ?? 'รายการทั่วไป';
          emoji = main?.emoji ?? '📄';
        }

        subExpense[subName] = (subExpense[subName] ?? 0.0) + t.amount;
        subEmojiMap[subName] = emoji;
        if (parentName.isNotEmpty) subParentMap[subName] = parentName;
      }

      final sorted = subExpense.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topSub = sorted.first;
      final topPct = totalExpense > 0 ? (topSub.value / totalExpense * 100).toStringAsFixed(1) : '0';

      final buffer = StringBuffer('📊 **สรุปหมวดย่อยที่คู่คุณใช้เงินเยอะที่สุดประจำเดือนนี้:**\n\n');
      buffer.write('🏆 **อันดับ 1 (หมวดย่อย):** ${subEmojiMap[topSub.key]} **${topSub.key}** — **${CurrencyFormatter.format(topSub.value)}** ($topPct%)\n');
      if (subParentMap[topSub.key] != null) {
        buffer.write('   *(หมวดหลัก: ${subParentMap[topSub.key]})*\n\n');
      } else {
        buffer.write('\n');
      }

      buffer.write('**สัดส่วนตามหมวดย่อยอื่นๆ:**\n');
      for (var entry in sorted.skip(1).take(5)) {
        final pct = totalExpense > 0 ? (entry.value / totalExpense * 100).toStringAsFixed(1) : '0';
        final emoji = subEmojiMap[entry.key] ?? '•';
        buffer.write('• $emoji **${entry.key}:** ${CurrencyFormatter.format(entry.value)} ($pct%)\n');
      }

      // Check if any tracked subcategory budget is affected
      if (subcategoryBudgets.isNotEmpty) {
        buffer.write('\n🎯 **สถานะงบหมวดย่อยที่กำลังคุม (แบบ A):**\n');
        for (var b in subcategoryBudgets.entries) {
          final sCat = subCatMap[b.key];
          if (sCat != null) {
            final spentOnCat = subExpense[sCat.name] ?? 0.0;
            final remaining = b.value - spentOnCat;
            buffer.write('• ${sCat.emoji} ${sCat.name}: ${CurrencyFormatter.format(spentOnCat)} / ${CurrencyFormatter.format(b.value)} ');
            if (remaining >= 0) {
              buffer.write('(คงเหลือ **${CurrencyFormatter.format(remaining)}**)\n');
            } else {
              buffer.write('(⚠️ **เกินงบ ${CurrencyFormatter.format(-remaining)}**)\n');
            }
          }
        }
      }

      return buffer.toString();
    }

    // 1. Query: Subcategory Budgets Status (เช็กงบประมาณ / คุมงบ)
    if (cleanQuery.contains('งบ') || cleanQuery.contains('งบประมาณ') || cleanQuery.contains('คุมงบ')) {
      if (subcategoryBudgets.isEmpty) {
        return '🎯 **คู่ของคุณยังไม่ได้ตั้งงบหมวดย่อยไว้ครับ**\n\n'
            '💡 แนะนำ: คุณสามารถกดปุ่ม **"+ ตั้งงบหมวดแรก"** บนการ์ดคุมงบในหน้าหลัก เพื่อเลือกคุมหมวดย่อยที่เงินรั่วไหลง่าย เช่น ชานม/ขนม 🧋, กินหรู/ชาบู 🍲 หรือช้อปปิ้ง 🛒 ได้เลยครับ!';
      }

      final buffer = StringBuffer('🎯 **รายงานสถานะงบหมวดย่อยของคู่รักประจำเดือนนี้:**\n\n');
      for (var b in subcategoryBudgets.entries) {
        final sCat = subCatMap[b.key];
        final spent = expenses
            .where((t) => t.subCategoryId == b.key)
            .fold(0.0, (s, t) => s + t.amount);
        final budget = b.value;
        final pct = budget > 0 ? (spent / budget * 100).toStringAsFixed(0) : '0';
        final remaining = budget - spent;

        final emoji = sCat?.emoji ?? '🏷️';
        final name = sCat?.name ?? 'หมวดย่อย';

        if (spent > budget) {
          buffer.write('🔴 $emoji **$name:** ${CurrencyFormatter.format(spent)} / ${CurrencyFormatter.format(budget)} (เกินงบ ${CurrencyFormatter.format(-remaining)} ⚠️)\n');
        } else if (spent / budget >= 0.7) {
          buffer.write('🟡 $emoji **$name:** ${CurrencyFormatter.format(spent)} / ${CurrencyFormatter.format(budget)} (ใช้ไป $pct% เหลือ ${CurrencyFormatter.format(remaining)})\n');
        } else {
          buffer.write('🟢 $emoji **$name:** ${CurrencyFormatter.format(spent)} / ${CurrencyFormatter.format(budget)} (ใช้ไป $pct% เหลือ ${CurrencyFormatter.format(remaining)})\n');
        }
      }
      return buffer.toString();
    }

    // 2. Query: Top spending Main categories
    if (cleanQuery.contains('หมวด') || cleanQuery.contains('เยอะสุด') || cleanQuery.contains('กับอะไร') || cleanQuery.contains('อะไรเยอะ')) {
      if (expenses.isEmpty) {
        return '💕 ในเดือนนี้คู่ของคุณยังไม่มีบันทึกรายจ่ายเข้ามาเลยครับ เริ่มต้นจดบันทึกเพื่อติดตามงบด้วยกันได้เลย!';
      }

      final Map<String, double> catExpense = {};
      final Map<String, String> catEmoji = {};
      for (var t in expenses) {
        final main = mainCatMap[t.mainCategoryId];
        final catName = main?.name ?? 'หมวดหมู่ทั่วไป';
        catExpense[catName] = (catExpense[catName] ?? 0) + t.amount;
        catEmoji[catName] = main?.emoji ?? '📁';
      }

      final sorted = catExpense.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topCat = sorted.first;
      final topPct = totalExpense > 0 ? (topCat.value / totalExpense * 100).toStringAsFixed(1) : '0';

      final buffer = StringBuffer('📊 **สรุปหมวดหมู่หลักที่คู่คุณใช้เงินเยอะที่สุดประจำเดือนนี้:**\n\n');
      buffer.write('🏆 **อันดับ 1:** ${catEmoji[topCat.key]} **${topCat.key}** — **${CurrencyFormatter.format(topCat.value)}** ($topPct%)\n\n');
      buffer.write('**สัดส่วนตามหมวดหมู่อื่นๆ:**\n');
      for (var entry in sorted) {
        final pct = totalExpense > 0 ? (entry.value / totalExpense * 100).toStringAsFixed(1) : '0';
        buffer.write('• ${catEmoji[entry.key]} ${entry.key}: ${CurrencyFormatter.format(entry.value)} ($pct%)\n');
      }
      return buffer.toString();
    }

    // 3. Query: Partner Spending Comparison / Habits
    if (cleanQuery.contains('ใคร') || cleanQuery.contains('เทียบ') || cleanQuery.contains('จ่ายเยอะ') || cleanQuery.contains('จ่าย') || cleanQuery.contains('นิสัย') || cleanQuery.contains('พฤติกรรม')) {
      final Map<String, double> partnerExpense = {};
      final Map<String, Map<String, double>> partnerCatBreakdown = {};

      for (var t in expenses) {
        final name = (t.createdByName != null && t.createdByName!.isNotEmpty)
            ? t.createdByName!
            : (currentUserName ?? 'สมาชิกคู่รัก');
        partnerExpense[name] = (partnerExpense[name] ?? 0) + t.amount;

        partnerCatBreakdown.putIfAbsent(name, () => {});
        final catName = mainCatMap[t.mainCategoryId]?.name ?? 'ทั่วไป';
        partnerCatBreakdown[name]![catName] = (partnerCatBreakdown[name]![catName] ?? 0) + t.amount;
      }

      if (partnerExpense.isEmpty) {
        return 'ยังไม่มีข้อมูลการจ่ายเงินของเดือนนี้ครับ';
      }

      final sorted = partnerExpense.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final buffer = StringBuffer('👩‍❤️‍👨 **สถิติและพฤติกรรมการจ่ายเงินของคู่เรา (AI Dynamic Learning):**\n\n');
      for (var entry in sorted) {
        final pct = totalExpense > 0 ? (entry.value / totalExpense * 100).toStringAsFixed(1) : '0';
        buffer.write('• **${entry.key}:** จ่ายรวม **${CurrencyFormatter.format(entry.value)}** ($pct%)\n');
        
        final topCatOfPartner = partnerCatBreakdown[entry.key]?.entries.toList();
        if (topCatOfPartner != null && topCatOfPartner.isNotEmpty) {
          topCatOfPartner.sort((a, b) => b.value.compareTo(a.value));
          buffer.write('   *👉 ส่วนใหญ่หมดไปกับ: ${topCatOfPartner.first.key} (${CurrencyFormatter.format(topCatOfPartner.first.value)})*\n');
        }
      }
      return buffer.toString();
    }

    // 4. Query: Total expenses / Summary
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

    // 5. Query: Predictions
    if (cleanQuery.contains('ทำนาย') || cleanQuery.contains('ล่วงหน้า') || cleanQuery.contains('อนาคต')) {
      final predictions = predictUpcomingExpenses(transactions);
      final buffer = StringBuffer('🔮 **ผลวิเคราะห์ทำนายบิลล่วงหน้าของ AI:**\n\n');
      for (var p in predictions) {
        buffer.write('${p.iconEmoji} **${p.title}:** ${p.description}\n\n');
      }
      return buffer.toString();
    }

    // Default friendly response
    return '🤖 **สวัสดีครับ! ผมคือ AI ที่ปรึกษาการเงินคู่รัก Kapookluxx** 💕\n\n'
        'เดือนนี้คู่ของคุณใช้จ่ายรวม **${CurrencyFormatter.format(totalExpense)}** '
        'คุณสามารถถามผมเพิ่มเติมได้ เช่น:\n'
        '• *"หมวดย่อยใช้อะไรเยอะสุด?"*\n'
        '• *"เช็กสถานะงบประมาณหมวดย่อย"*\n'
        '• *"ใครจ่ายเงินมากกว่ากันในเดือนนี้?"*\n'
        '• *"สรุปรายรับรายจ่ายเดือนนี้"*';
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
