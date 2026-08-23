import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transaction_provider.dart';
import 'category_provider.dart';

class CategoryReportData {
  final String categoryId;
  final String categoryName;
  final String colorHex;
  final String emoji;
  final double amount;
  final double percentage;

  CategoryReportData({
    required this.categoryId,
    required this.categoryName,
    required this.colorHex,
    required this.emoji,
    required this.amount,
    required this.percentage,
  });
}

class DailyReportData {
  final DateTime date;
  final double income;
  final double expense;

  DailyReportData({
    required this.date,
    required this.income,
    required this.expense,
  });
}

class MonthSummaryReport {
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final double totalTaxDeductible;
  final List<CategoryReportData> categoryBreakdown;
  final List<DailyReportData> dailyTrend;

  MonthSummaryReport({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.totalTaxDeductible,
    required this.categoryBreakdown,
    required this.dailyTrend,
  });
}

final reportProvider = Provider<MonthSummaryReport>((ref) {
  final transactions = ref.watch(filteredTransactionsProvider);
  final mainCategories = ref.watch(mainCategoriesProvider);
  
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  double totalTaxDeductible = 0.0;
  
  Map<String, double> categoryAmounts = {};
  Map<int, DailyReportData> dailyMap = {};
  
  // Initialize daily trends for all days in the current selected month
  final filters = ref.watch(transactionFiltersProvider);
  final daysInMonth = DateTime(filters.selectedMonth.year, filters.selectedMonth.month + 1, 0).day;
  
  for (int d = 1; d <= daysInMonth; d++) {
    final dayDate = DateTime(filters.selectedMonth.year, filters.selectedMonth.month, d);
    dailyMap[d] = DailyReportData(date: dayDate, income: 0, expense: 0);
  }

  for (var tx in transactions) {
    if (tx.type == 'income') {
      totalIncome += tx.amount;
      
      final currentDay = tx.date.day;
      if (dailyMap.containsKey(currentDay)) {
        final current = dailyMap[currentDay]!;
        dailyMap[currentDay] = DailyReportData(
          date: current.date,
          income: current.income + tx.amount,
          expense: current.expense,
        );
      }
    } else {
      totalExpense += tx.amount;
      
      // Accumulate category spending
      categoryAmounts[tx.mainCategoryId] = (categoryAmounts[tx.mainCategoryId] ?? 0.0) + tx.amount;
      
      final currentDay = tx.date.day;
      if (dailyMap.containsKey(currentDay)) {
        final current = dailyMap[currentDay]!;
        dailyMap[currentDay] = DailyReportData(
          date: current.date,
          income: current.income,
          expense: current.expense + tx.amount,
        );
      }
    }

    if (tx.isTaxDeductible) {
      totalTaxDeductible += tx.amount;
    }
  }

  // Calculate category breakdown percentages
  List<CategoryReportData> breakdown = [];
  final mainCatMap = {for (var c in mainCategories) c.id: c};
  
  categoryAmounts.forEach((catId, amount) {
    final cat = mainCatMap[catId];
    final catName = cat?.name ?? 'อื่นๆ';
    final color = cat?.color ?? '#9E9E9E';
    final emoji = cat?.emoji ?? '📁';
    final percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0.0;
    
    breakdown.add(CategoryReportData(
      categoryId: catId,
      categoryName: catName,
      colorHex: color,
      emoji: emoji,
      amount: amount,
      percentage: percentage,
    ));
  });

  // Sort breakdown by amount descending
  breakdown.sort((a, b) => b.amount.compareTo(a.amount));

  // Convert daily map to sorted list
  List<DailyReportData> trend = dailyMap.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  return MonthSummaryReport(
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    netBalance: totalIncome - totalExpense,
    totalTaxDeductible: totalTaxDeductible,
    categoryBreakdown: breakdown,
    dailyTrend: trend,
  );
});
