import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/report_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/csv_exporter.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final mainCats = ref.watch(mainCategoriesProvider);
    final subCats = ref.watch(subCategoriesProvider);
    final wallets = ref.watch(walletsProvider);
    final transactions = ref.watch(filteredTransactionsProvider);

    final theme = Theme.of(context);

    // Dynamic month name for title
    final monthName = DateFormatter.formatSmartMonth(filters.selectedMonth);

    // Export function
    Future<void> _exportCsv() async {
      try {
        final filename = 'รายงานการเงิน_${filters.selectedMonth.year}_${filters.selectedMonth.month}';
        await CsvExporter.shareCsv(
          transactions: transactions,
          mainCategories: mainCats,
          subCategories: subCats,
          wallets: wallets,
          filename: filename,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งออกไม่สำเร็จ: $e')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงานการเงิน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.primary),
            tooltip: 'ส่งออก CSV',
            onPressed: transactions.isEmpty ? null : _exportCsv,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Header summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'ข้อมูลสรุปประจำเดือน $monthName',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('รายรับรวม', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(report.totalIncome),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.income),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('รายจ่ายรวม', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(report.totalExpense),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.expense),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ดุลการเงินคงเหลือ (สุทธิ)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(
                          CurrencyFormatter.format(report.netBalance, showSign: true),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: report.netBalance >= 0 ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Income vs Expense bar ratio
            const Text('สัดส่วนรายรับ-รายจ่าย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (report.totalIncome == 0 && report.totalExpense == 0)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('ไม่มีข้อมูลธุรกรรมสำหรับเดือนนี้')),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 24,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              if (report.totalIncome > 0)
                                Expanded(
                                  flex: (report.totalIncome * 100).toInt(),
                                  child: Container(color: AppColors.income),
                                ),
                              if (report.totalExpense > 0)
                                Expanded(
                                  flex: (report.totalExpense * 100).toInt(),
                                  child: Container(color: AppColors.expense),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.income, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(
                                'รายรับ (${(report.totalIncome / (report.totalIncome + report.totalExpense) * 100).toStringAsFixed(1)}%)',
                                style: const TextStyle(fontSize: 12),
                              )
                            ],
                          ),
                          Row(
                            children: [
                              Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppColors.expense, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(
                                'รายจ่าย (${(report.totalExpense / (report.totalIncome + report.totalExpense) * 100).toStringAsFixed(1)}%)',
                                style: const TextStyle(fontSize: 12),
                              )
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Couple Expense Split Summary (สรุปสัดส่วนการจ่ายของคู่รัก 👩‍❤️‍👨)
            const Text('สรุปสัดส่วนการจ่ายของคู่รัก 💕', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            () {
              final expenses = transactions.where((t) => t.type == 'expense').toList();
              if (expenses.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('ยังไม่มีข้อมูลการจ่ายเงินในเดือนนี้')),
                  ),
                );
              }

              final userProfile = ref.watch(userProfileProvider).value;

              // Group expenses by createdByName (fallback to userProfile.nickname if current user)
              final Map<String, double> partnerExpenseMap = {};
              double totalGroupedExpense = 0;

              for (var tx in expenses) {
                final name = (userProfile != null && tx.createdByUserId == userProfile.id && userProfile.nickname.isNotEmpty)
                    ? userProfile.nickname
                    : (tx.createdByName != null && tx.createdByName!.isNotEmpty
                        ? tx.createdByName!
                        : 'ผู้ใช้ร่วม');
                partnerExpenseMap[name] = (partnerExpenseMap[name] ?? 0) + tx.amount;
                totalGroupedExpense += tx.amount;
              }

              final partnerEntries = partnerExpenseMap.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final paletteColors = [
                AppColors.primary,
                const Color(0xFF1E88E5),
                const Color(0xFFFF9800),
                const Color(0xFF4CAF50),
              ];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'เปรียบเทียบการจ่ายประจำเดือน (${partnerEntries.length} สมาชิก)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Progress bar showing partner breakdown ratio
                      SizedBox(
                        height: 22,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: partnerEntries.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              final ratio = totalGroupedExpense > 0 ? item.value / totalGroupedExpense : 0.0;
                              final color = paletteColors[idx % paletteColors.length];
                              return Expanded(
                                flex: (ratio * 1000).toInt().clamp(1, 1000),
                                child: Container(color: color),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // List of partners with percentage and total amount
                      ...partnerEntries.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final name = item.key;
                        final amount = item.value;
                        final pct = totalGroupedExpense > 0 ? (amount / totalGroupedExpense * 100) : 0.0;
                        final color = paletteColors[idx % paletteColors.length];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: color.withOpacity(0.2),
                                    child: Icon(Icons.person, size: 14, color: color),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${pct.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${CurrencyFormatter.format(amount)})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }(),
            const SizedBox(height: 24),

            // Tax deductible info card
            Card(
              color: AppColors.taxDeductibleLight.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.taxDeductible, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.taxDeductible.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.gavel, color: AppColors.taxDeductible, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ยอดเงินสะสมสำหรับลดหย่อนภาษี',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.taxDeductible),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(report.totalTaxDeductible),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.taxDeductible),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category spending pie breakdown
            const Text('สัดส่วนค่าใช้จ่ายตามหมวดหมู่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (report.categoryBreakdown.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('ไม่มีประวัติการใช้จ่ายของเดือนนี้')),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Pie chart graphic
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 50,
                            sections: report.categoryBreakdown.map((data) {
                              final color = AppColors.fromHex(data.colorHex);
                              return PieChartSectionData(
                                color: color,
                                value: data.amount,
                                title: '${data.percentage.toStringAsFixed(0)}%',
                                radius: 40,
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Legend / breakdown list
                      ...report.categoryBreakdown.map((item) {
                        final color = AppColors.fromHex(item.colorHex);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Text(item.emoji, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.categoryName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${item.percentage.toStringAsFixed(1)}% (${CurrencyFormatter.format(item.amount)})',
                                style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
