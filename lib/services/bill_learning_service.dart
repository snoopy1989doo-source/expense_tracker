import 'package:flutter/material.dart';
import '../models/sub_category.dart';
import '../models/transaction_item.dart';

class BillStatusInfo {
  final bool hasPaidThisMonth;
  final double paidAmountThisMonth;
  final int dueDay;
  final int daysRemaining;
  final bool isDueToday;
  final bool isOverdue;
  final String statusText;
  final Color statusColor;

  BillStatusInfo({
    required this.hasPaidThisMonth,
    required this.paidAmountThisMonth,
    required this.dueDay,
    required this.daysRemaining,
    required this.isDueToday,
    required this.isOverdue,
    required this.statusText,
    required this.statusColor,
  });
}

class DiscoveredBill {
  final String subCategoryId;
  final String title;
  final String emoji;
  final double monthlyAverage;
  final int detectedDueDay;
  final int transactionCount;

  DiscoveredBill({
    required this.subCategoryId,
    required this.title,
    required this.emoji,
    required this.monthlyAverage,
    required this.detectedDueDay,
    required this.transactionCount,
  });
}

class BillLearningService {
  /// Calculate monthly average expense for a specific subcategory
  static double calculateMonthlyAverage(List<TransactionItem> transactions, String subCategoryId) {
    final catTxs = transactions.where((t) => t.type == 'expense' && t.subCategoryId == subCategoryId).toList();
    if (catTxs.isEmpty) return 0.0;

    // Group by Year-Month
    final Map<String, double> monthlySums = {};
    for (final tx in catTxs) {
      final key = '${tx.date.year}-${tx.date.month}';
      monthlySums[key] = (monthlySums[key] ?? 0.0) + tx.amount;
    }

    if (monthlySums.isEmpty) return 0.0;
    final total = monthlySums.values.fold(0.0, (sum, val) => sum + val);
    return total / monthlySums.length;
  }

  /// Detect the most common day of month (1-31) when user pays this category
  static int detectTypicalDueDay(List<TransactionItem> transactions, String subCategoryId, {int defaultDay = 25}) {
    final catTxs = transactions.where((t) => t.type == 'expense' && t.subCategoryId == subCategoryId).toList();
    if (catTxs.isEmpty) return defaultDay;

    // Frequency of days of month
    final Map<int, int> dayFrequency = {};
    for (final tx in catTxs) {
      final day = tx.date.day;
      dayFrequency[day] = (dayFrequency[day] ?? 0) + 1;
    }

    int bestDay = defaultDay;
    int maxCount = 0;
    dayFrequency.forEach((day, count) {
      if (count > maxCount) {
        maxCount = count;
        bestDay = day;
      }
    });

    return bestDay;
  }

  /// Analyze bill payment status for the current month
  static BillStatusInfo getBillStatus(
    List<TransactionItem> transactions,
    String subCategoryId, {
    int? configuredDueDay,
    DateTime? currentMonth,
  }) {
    final now = DateTime.now();
    final targetMonth = currentMonth ?? now;
    final dueDay = configuredDueDay ?? detectTypicalDueDay(transactions, subCategoryId, defaultDay: 25);

    // Filter transactions in this category for the target month
    final monthTxs = transactions.where((t) =>
        t.type == 'expense' &&
        t.subCategoryId == subCategoryId &&
        t.date.year == targetMonth.year &&
        t.date.month == targetMonth.month).toList();

    final hasPaid = monthTxs.isNotEmpty;
    final paidAmount = monthTxs.fold(0.0, (sum, t) => sum + t.amount);

    // If already paid this month
    if (hasPaid) {
      return BillStatusInfo(
        hasPaidThisMonth: true,
        paidAmountThisMonth: paidAmount,
        dueDay: dueDay,
        daysRemaining: 0,
        isDueToday: false,
        isOverdue: false,
        statusText: '✅ จ่ายแล้วเดือนนี้',
        statusColor: const Color(0xFF10B981),
      );
    }

    // If checking a past month and not paid
    final isCurrentMonth = targetMonth.year == now.year && targetMonth.month == now.month;
    if (!isCurrentMonth) {
      return BillStatusInfo(
        hasPaidThisMonth: false,
        paidAmountThisMonth: 0,
        dueDay: dueDay,
        daysRemaining: 0,
        isDueToday: false,
        isOverdue: true,
        statusText: '⚠️ ยังไม่ได้จ่าย',
        statusColor: const Color(0xFFEF4444),
      );
    }

    // Current month countdown
    final today = now.day;
    if (today == dueDay) {
      return BillStatusInfo(
        hasPaidThisMonth: false,
        paidAmountThisMonth: 0,
        dueDay: dueDay,
        daysRemaining: 0,
        isDueToday: true,
        isOverdue: false,
        statusText: '🚨 ครบกำหนดวันนี้!',
        statusColor: const Color(0xFFF59E0B),
      );
    } else if (today < dueDay) {
      final daysLeft = dueDay - today;
      return BillStatusInfo(
        hasPaidThisMonth: false,
        paidAmountThisMonth: 0,
        dueDay: dueDay,
        daysRemaining: daysLeft,
        isDueToday: false,
        isOverdue: false,
        statusText: '⏳ อีก $daysLeft วัน (วันที่ $dueDay)',
        statusColor: const Color(0xFF3B82F6),
      );
    } else {
      final daysOver = today - dueDay;
      return BillStatusInfo(
        hasPaidThisMonth: false,
        paidAmountThisMonth: 0,
        dueDay: dueDay,
        daysRemaining: 0,
        isDueToday: false,
        isOverdue: true,
        statusText: '⚠️ เลยกำหนด $daysOver วัน',
        statusColor: const Color(0xFFEF4444),
      );
    }
  }

  /// Automatically discover recurring bills from expense history that aren't yet planned
  static List<DiscoveredBill> discoverUnplannedRecurringBills(
    List<TransactionItem> transactions,
    Map<String, double> existingBudgets,
    List<SubCategory> subCategories,
  ) {
    final expenses = transactions.where((t) => t.type == 'expense' && t.subCategoryId.isNotEmpty).toList();
    if (expenses.isEmpty) return [];

    // Group by subcategory: count distinct months and total amount
    final Map<String, Set<String>> subCatMonths = {};
    final Map<String, List<TransactionItem>> subCatTxs = {};

    for (final tx in expenses) {
      subCatMonths.putIfAbsent(tx.subCategoryId, () => {}).add('${tx.date.year}-${tx.date.month}');
      subCatTxs.putIfAbsent(tx.subCategoryId, () => []).add(tx);
    }

    final List<DiscoveredBill> discovered = [];

    for (final entry in subCatMonths.entries) {
      final subCatId = entry.key;
      // Skip if already in budget plan
      if (existingBudgets.containsKey(subCatId)) continue;

      final monthsCount = entry.value.length;
      final txList = subCatTxs[subCatId] ?? [];

      // Find subcategory metadata
      final subCat = subCategories.firstWhere(
        (s) => s.id == subCatId,
        orElse: () => SubCategory(id: subCatId, mainCategoryId: '', name: 'ค่าใช้จ่าย', emoji: '🧾', color: '#607D8B', order: 0),
      );

      final lowerName = subCat.name.toLowerCase();
      final isKnownBillCategory = lowerName.contains('ไฟ') ||
          lowerName.contains('น้ำ') ||
          lowerName.contains('เน็ต') ||
          lowerName.contains('บ้าน') ||
          lowerName.contains('ห้อง') ||
          lowerName.contains('โทรศัพท์') ||
          lowerName.contains('netflix') ||
          lowerName.contains('spotify') ||
          lowerName.contains('ประกัน');

      // If category appears in >= 2 distinct months OR is a known recurring bill type
      if (monthsCount >= 2 || (isKnownBillCategory && txList.isNotEmpty)) {
        final avg = calculateMonthlyAverage(transactions, subCatId);
        final dueDay = detectTypicalDueDay(transactions, subCatId);

        discovered.add(DiscoveredBill(
          subCategoryId: subCatId,
          title: subCat.name,
          emoji: subCat.emoji,
          monthlyAverage: avg > 0 ? avg : (txList.first.amount),
          detectedDueDay: dueDay,
          transactionCount: txList.length,
        ));
      }
    }

    // Sort by monthly average descending
    discovered.sort((a, b) => b.monthlyAverage.compareTo(a.monthlyAverage));
    return discovered;
  }
}
