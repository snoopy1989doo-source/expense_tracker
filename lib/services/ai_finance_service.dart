import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  /// Sanitize user-provided API key from whitespace, quotes, and accidental prefixes
  static String sanitizeApiKey(String raw) {
    var key = raw.trim();
    key = key.replaceAll('"', '').replaceAll("'", "");
    if (key.toLowerCase().startsWith('key=')) {
      key = key.substring(4).trim();
    }
    if (key.toLowerCase().startsWith('bearer ')) {
      key = key.substring(7).trim();
    }
    return key;
  }

  /// Test Google Gemini API Key validity
  static Future<Map<String, dynamic>> testApiKey(String apiKey) async {
    final cleanKey = sanitizeApiKey(apiKey);
    if (cleanKey.isEmpty) {
      return {'success': false, 'message': 'กรุณากรอก API Key ก่อนกดทดสอบครับ'};
    }
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$cleanKey',
      );
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': 'ตอบสั้นๆ ว่าพร้อมใช้งาน'}
                  ]
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return {'success': true, 'message': '✅ เชื่อมต่อ Google Gemini API สำเร็จสมบูรณ์! พร้อมใช้งาน'};
      } else {
        final bodyStr = utf8.decode(response.bodyBytes);
        try {
          final errJson = jsonDecode(bodyStr);
          final msg = errJson['error']?['message'] ?? 'Status ${response.statusCode}';
          return {'success': false, 'message': '❌ เชื่อมต่อไม่สำเร็จ (${response.statusCode}): $msg'};
        } catch (_) {
          return {'success': false, 'message': '❌ รหัส API Key ไม่ถูกต้อง (Status ${response.statusCode})'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': '❌ ไม่สามารถติดต่อ Google API ได้: $e'};
    }
  }

  /// Asynchronous AI Finance Engine with Google Gemini LLM + Graceful Local Fallback
  static Future<String> answerUserQueryAsync({
    required String query,
    required List<TransactionItem> transactions,
    required List<MainCategory> categories,
    required List<SubCategory> subCategories,
    required Map<String, double> subcategoryBudgets,
    required String? currentUserName,
    String? partnerName,
  }) async {
    // 1. Try Google Gemini API if configured
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('gemini_api_key') ?? '';

      if (apiKey.trim().isNotEmpty) {
        final geminiReply = await _callGeminiApi(
          apiKey: apiKey.trim(),
          query: query,
          transactions: transactions,
          categories: categories,
          subCategories: subCategories,
          subcategoryBudgets: subcategoryBudgets,
          currentUserName: currentUserName,
          partnerName: partnerName,
        );

        if (geminiReply != null && geminiReply.trim().isNotEmpty) {
          return geminiReply.trim();
        }
      }
    } catch (e) {
      debugPrint('🛡️ [Gemini Safe Fallback] Handled error seamlessly: $e');
    }

    // 2. Safe Fallback: Local Smart Engine (Always works 100%, 0 crash guarantee)
    return answerUserQuery(
      query: query,
      transactions: transactions,
      categories: categories,
      subCategories: subCategories,
      subcategoryBudgets: subcategoryBudgets,
      currentUserName: currentUserName,
      partnerName: partnerName,
    );
  }

  /// Direct REST Call to Google Gemini API (Multi-model support + Clear error reporting)
  static Future<String?> _callGeminiApi({
    required String apiKey,
    required String query,
    required List<TransactionItem> transactions,
    required List<MainCategory> categories,
    required List<SubCategory> subCategories,
    required Map<String, double> subcategoryBudgets,
    required String? currentUserName,
    String? partnerName,
  }) async {
    final cleanKey = sanitizeApiKey(apiKey);
    if (cleanKey.isEmpty) return null;

    final now = DateTime.now();
    final currentMonthTxs = transactions.where((t) {
      return t.date.year == now.year && t.date.month == now.month;
    }).toList();

    final expenses = currentMonthTxs.where((t) => t.type == 'expense').toList();
    final income = currentMonthTxs.where((t) => t.type == 'income').toList();
    final totalExpense = expenses.fold(0.0, (sum, t) => sum + t.amount);
    final totalIncome = income.fold(0.0, (sum, t) => sum + t.amount);
    final netBalance = totalIncome - totalExpense;

    final daysTogether = now.difference(DateTime(2023, 1, 17)).inDays;

    final mainCatMap = {for (var c in categories) c.id: c};
    final subCatMap = {for (var s in subCategories) s.id: s};

    // Build spending summary by subcategory
    final Map<String, double> subExpense = {};
    for (var t in expenses) {
      final name = subCatMap[t.subCategoryId]?.name ?? t.note ?? mainCatMap[t.mainCategoryId]?.name ?? 'ทั่วไป';
      subExpense[name] = (subExpense[name] ?? 0) + t.amount;
    }
    final topSubList = subExpense.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topSubSummary = topSubList.take(5).map((e) => '${e.key}: ${CurrencyFormatter.format(e.value)}').join(', ');

    // System prompt with full family & financial context
    final promptWithContext = '''
[คำสั่งระบบ: คุณคือ "AI ที่ปรึกษาการเงินและผู้ช่วยชีวิตคู่" ประจำแอป Kapookluxx ตอบคำถามอย่างเป็นธรรมชาติ น่ารัก อบอุ่น และเป็นกันเอง ห้ามตอบเป็นสคริปต์แข็งๆ]

ข้อมูลบริบทชีวิตคู่และครอบครัวจริง (Real Context):
- ผู้ใช้: ต๋อง (อายุ 23 ปี, ทำงานเป็นช่างไฟฟ้าระบบ Utility ในโรงงาน ฐานเงินเดือน ~12,000-15,000 บาท)
- แฟนสาว: ฝน (อายุ 23 ปี, เกิด 15 มกราคม 2546)
- วันครบรอบเป็นแฟนกัน: 17 มกราคม 2566 (คบกันมาแล้ว $daysTogether วัน)
- วันเกิดต๋อง: 17 มกราคม 2546 (วันเดียวกับวันครบรอบ)
- สมาชิกสี่ขาประจำบ้าน: น้องแมว 2 ตัว ชื่อ "กังฟู" 🥋 (สุดซน) และ "โอเลี้ยง" ☕ (แมวดำขี้อ้อน)
- เป้าหมายใหญ่ของชีวิตคู่:
  1. ปลดหนี้คุณแม่ 50,000 บาท (Priority 1 เพื่อความสุขและความภาคภูมิใจของครอบครัว)
  2. เก็บเงินดาวน์รถยนต์ BMW มือสอง (เป้าหมาย 260,000 บาท) เพื่อพาแม่และฝนเที่ยวอย่างมีความสุข
  3. โปรเจกต์ "ร้านของชำบ้านดวด" (ต.สวนแตง อ.ละแม จ.ชุมพร) และเปิดมุมน้ำชงเครื่องดื่มให้ฝนมาขาย
  4. กองทุนสร้างครอบครัวและแต่งงานในอนาคต

สรุปข้อมูลการเงินจริงเดือนนี้:
- รายรับรวม: ${CurrencyFormatter.format(totalIncome)}
- รายจ่ายรวม: ${CurrencyFormatter.format(totalExpense)}
- คงเหลือสุทธิ: ${CurrencyFormatter.format(netBalance)}
- รายการใช้จ่ายเด่น: $topSubSummary

แนวทางการตอบ:
- ตอบเป็นภาษาไทยอย่างอบอุ่น เป็นกันเอง สุภาพ น่ารัก สไตล์ที่ปรึกษาการเงินคู่รักตัวจริง (เรียกผู้ใช้ว่า "ต๋อง" และแฟนว่า "ฝน")
- ตอบคำถามทุกหัวข้อ (ทั้งเรื่องอาหาร, การเงิน, การวางแผนชีวิต, วันสำคัญ, กำลังใจ หรือเรื่องทั่วไป) อย่างมีชีวิตชีวาและสร้างสรรค์
- ใช้ Emoji ประกอบน่ารักๆ จัดรูปแบบ Markdown ให้อ่านง่าย

คำถามจากต๋อง:
$query
''';

    final models = ['gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-3.7-flash', 'gemini-flash-latest'];

    for (final model in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$cleanKey',
        );

        final requestBody = jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': promptWithContext}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.8,
            'maxOutputTokens': 1000,
          }
        });

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBody,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          }
        } else {
          final bodyStr = utf8.decode(response.bodyBytes);
          debugPrint('🚨 Gemini API [$model] Error ${response.statusCode}: $bodyStr');
          if (response.statusCode == 400 || response.statusCode == 403) {
            try {
              final errJson = jsonDecode(bodyStr);
              final errMsg = errJson['error']?['message'] ?? 'API Key ไม่ถูกต้อง';
              return '⚠️ **Google Gemini แจ้งเตือน (${response.statusCode}):**\n$errMsg\n\n👉 *กรุณากดไอคอนกุญแจ 🔑 ด้านบนเพื่อตรวจเช็กหรือวาง API Key จาก Google AI Studio ใหม่อีกครั้งครับ*';
            } catch (_) {
              return '⚠️ **รหัส API Key ไม่ถูกต้อง (Status ${response.statusCode})**\n\n👉 *กรุณากดไอคอนกุญแจ 🔑 เพื่อตรวจเช็ก API Key ครับ*';
            }
          }
        }
      } catch (e) {
        debugPrint('Gemini model $model exception: $e');
      }
    }
    return null;
  }

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

    // 4. Query: D-Day / Special Anniversaries & Birthdays
    if (cleanQuery.contains('วันสำคัญ') || cleanQuery.contains('วันเกิด') || cleanQuery.contains('ครบรอบ') || cleanQuery.contains('คบ') || cleanQuery.contains('กี่วัน')) {
      final now = DateTime.now();
      final anniversary = DateTime(2023, 1, 17);
      final daysTogether = now.difference(anniversary).inDays;

      // Next birthdays
      final thisYear = now.year;
      var nextFonBirthday = DateTime(thisYear, 1, 15);
      if (nextFonBirthday.isBefore(now)) {
        nextFonBirthday = DateTime(thisYear + 1, 1, 15);
      }
      final daysToFon = nextFonBirthday.difference(now).inDays + 1;

      var nextTongBirthday = DateTime(thisYear, 1, 17);
      if (nextTongBirthday.isBefore(now)) {
        nextTongBirthday = DateTime(thisYear + 1, 1, 17);
      }
      final daysToTong = nextTongBirthday.difference(now).inDays + 1;

      return '💖 **วันสำคัญของคู่รัก ต๋อง & ฝน:**\n\n'
          '• 👩‍❤️‍👨 **วันครบรอบเป็นแฟนกัน:** 17 มกราคม 2566\n'
          '  👉 **คบกันมาแล้ว:** **$daysTogether วัน** แห่งความรักและความผูกพัน! 💕\n\n'
          '• 🎂 **วันเกิดฝน:** 15 มกราคม *(อีกประมาณ $daysToFon วัน)*\n'
          '• 🎂 **วันเกิดต๋อง & วันครบรอบ:** 17 มกราคม *(อีกประมาณ $daysToTong วัน)*\n'
          '• 🐱 **สมาชิกสี่ขา:** น้องกังฟู 🥋 และ น้องโอเลี้ยง ☕🐾\n\n'
          '💡 *คำแนะนำ:* เริ่มหยอดกระปุกของขวัญวันเกิดและวันครบรอบเดือนละนิด เพื่อเซอร์ไพรส์แฟนแบบสบายกระเป๋าได้เลยครับ! ✨';
    }

    // 5. Query: Cats (กังฟู & โอเลี้ยง)
    if (cleanQuery.contains('แมว') || cleanQuery.contains('กังฟู') || cleanQuery.contains('โอเลี้ยง')) {
      double catExpense = 0;
      for (var t in expenses) {
        final note = t.note?.toLowerCase() ?? '';
        final subName = subCatMap[t.subCategoryId ?? '']?.name.toLowerCase() ?? '';
        if (note.contains('แมว') || note.contains('กังฟู') || note.contains('โอเลี้ยง') || note.contains('ทราย') || note.contains('อาหารแมว') || subName.contains('แมว')) {
          catExpense += t.amount;
        }
      }
      return '🐱🐾 **รายงานค่าดูแลน้องแมว (กังฟู & โอเลี้ยง):**\n\n'
          '• ยอดค่าใช้จ่ายดูแลน้องแมวในเดือนนี้: **${CurrencyFormatter.format(catExpense)}**\n'
          '• สมาชิกตัวแสบ: **กังฟู** 🥋 (สุดคึก) และ **โอเลี้ยง** ☕ (แมวดำสุดอ้อน)\n\n'
          '${catExpense > 0 ? "ดูแลลูกๆ ได้ดีมากครับ อย่าลืมกอดและให้รางวัลขนมแมวเลียด้วยนะคร้าบ 💕" : "ยังไม่มีรายการค่าอาหารหรือทรายแมวบันทึกเข้ามาในเดือนนี้ครับ"}';
    }

    // 6. Query: Total expenses / Summary
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

    // 8. Query: Food & Meals (กินอะไรดี / หิว / เมนู)
    if (cleanQuery.contains('กิน') || cleanQuery.contains('อาหาร') || cleanQuery.contains('หิว') || cleanQuery.contains('เมนู') || cleanQuery.contains('มื้อ')) {
      final foodIdeas = [
        '🍲 **เมนูคู่รักประหยัดงบ & อบอุ่น:** ชวนฝนทำ "สุกี้หม้อรวม / ผัดกะเพราไข่ดาวคู่" กินที่ห้องด้วยกัน ทั้งสนุก อิ่มอร่อย และช่วยคุมงบการเงินได้ดีมากครับ! 🍳',
        '🥘 **เมนูแนะนำวันนี้:** ข้าวไข่ข้นกุ้ง / ข้าวผัดโบราณ ทำง่าย อิ่มอร่อย หรือจะออกไปกินก๋วยเตี๋ยวต้มยำร้านโปรดแถวบ้านคนละชามก็ได้นะคร้าบ 🍜',
        '🥩 **ไอเดียพิเศษ:** ถ้าอยากให้รางวัลตัวเองช่วงเงินเดือนออก ลองชวนฝนไปกินหมูกระทะ / ชาบูบุฟเฟต์สักมื้อ เติมพลังให้ชีวิตคู่มีความสุขเต็มร้อยครับ! 💕',
        '🎡 **คิดไม่ออกใช่ไหม?** ลองใช้ฟีเจอร์ **"วงล้อสุ่มอาหารคู่รัก"** ในแท็บคู่รัก ให้ระบบช่วยหมุนตัดสินใจเลือกมื้ออร่อยให้ต๋องกับฝนได้เลยครับ! 🎯',
      ];
      final seed = (now.day * 7 + now.hour + cleanQuery.length) % foodIdeas.length;
      return '🍱 **แนะนำเมนูอาหารสำหรับต๋อง & ฝน:**\n\n${foodIdeas[seed]}\n\n💡 *ทริกการเงิน:* คุมงบค่าอาหารวันละ ~150-200 บาท ช่วยให้ต๋องเก็บเงินดาวน์ BMW และปลดหนี้ให้แม่ได้เร็วขึ้นแน่นอนครับ! 🚗✨';
    }

    // 9. Query: BMW / Down payment / Family Goals
    if (cleanQuery.contains('bmw') || cleanQuery.contains('รถ') || cleanQuery.contains('ดาวน์')) {
      return '🚗💨 **แผนการออมเงินดาวน์ BMW ของต๋อง:**\n\n'
          '• 🎯 **เป้าหมายเงินดาวน์:** **260,000 บาท** (เพื่อผ่อนสบายๆ ไม่ตึงมือ)\n'
          '• 💖 **จุดประสงค์:** พาคุณแม่และน้องฝนไปเที่ยวเปิดหูเปิดตาอย่างมีความสุข\n'
          '• 💡 **กลยุทธ์:** เคลียร์หนี้คุณแม่ 50,000 บาทให้จบเป็น Priority 1 จากนั้นโฟกัสหยอดกระปุก BMW เต็มกำลังครับ สู้ๆ นะครับต๋องทำได้แน่นอน! ✌️🔥';
    }

    // 10. Query: Baan Duad Shop & Cafe for Fon
    if (cleanQuery.contains('บ้านดวด') || cleanQuery.contains('ร้านชำ') || cleanQuery.contains('ร้านค้า') || cleanQuery.contains('คาเฟ่') || cleanQuery.contains('น้ำชง')) {
      return '🏪☕ **โปรเจกต์ร้านของชำบ้านดวด & คาเฟ่น้ำชงของฝน:**\n\n'
          '• 📍 **พิกัด:** ต.สวนแตง อ.ละแม จ.ชุมพร\n'
          '• 💡 **ไอเดียธุรกิจ:** เปิดมุมร้านน้ำชง ชาไทย กาแฟโบราณ สมูทตี้ ให้ฝนดูแลสร้างรายได้เข้าครอบครัว\n'
          '• 🎯 **ความคืบหน้า:** สะสมทุนหมุนเวียนและอุปกรณ์ตั้งต้นไปทีละขั้น เป็นรากฐานสร้างอนาคตชีวิตคู่ที่มั่นคงมากๆ ครับ! 🌸✨';
    }

    // Default friendly response
    return '🤖 **สวัสดีครับต๋อง & ฝน! ผมคือ AI ที่ปรึกษาการเงินคู่รัก Kapookluxx** 💕\n\n'
        'เดือนนี้คู่ของเราใช้จ่ายรวม **${CurrencyFormatter.format(totalExpense)}** '
        'สามารถถามผมเพิ่มเติมได้เลยครับ เช่น:\n'
        '• *"พรุ่งนี้กินอะไรดี?"* 🍱\n'
        '• *"วันสำคัญของคู่เรา"* 💖\n'
        '• *"ค่าใช้จ่ายน้องแมว (กังฟู & โอเลี้ยง)"* 🐱\n'
        '• *"เป้าหมายเก็บเงินดาวน์ BMW"* 🚗\n'
        '• *"หมวดย่อยใช้อะไรเยอะสุด?"* 🏷️\n'
        '• *"เช็กสถานะงบประมาณหมวดย่อย"* 🎯';
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
