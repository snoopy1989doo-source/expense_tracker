import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/main_category.dart';
import '../../models/sub_category.dart';
import '../../providers/category_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/transaction_provider.dart';

class MoneyPlannerDialog extends ConsumerStatefulWidget {
  const MoneyPlannerDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MoneyPlannerDialog(),
    );
  }

  @override
  ConsumerState<MoneyPlannerDialog> createState() => _MoneyPlannerDialogState();
}

class _MoneyPlannerDialogState extends ConsumerState<MoneyPlannerDialog> {
  void _showAddOrEditBudgetDialog({SubCategory? existingSubCat, double? existingBudget}) {
    final subCats = ref.read(subCategoriesProvider);
    final mainCats = ref.read(mainCategoriesProvider);
    final currentBudgets = ref.read(subcategoryBudgetsProvider);

    final availableSubCats = existingSubCat != null
        ? subCats
        : subCats.where((s) => !currentBudgets.containsKey(s.id)).toList();

    if (availableSubCats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณได้ตั้งงบเตรียมเงินให้กับทุกหมวดย่อยเรียบร้อยแล้ว')),
      );
      return;
    }

    String selectedSubCatId = existingSubCat?.id ?? availableSubCats.first.id;
    final amountController = TextEditingController(
      text: existingBudget != null ? existingBudget.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  existingSubCat != null ? '✏️ ปรับงบเตรียมเงิน' : '🎯 เตรียมเงินล่วงหน้า',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'กำหนดจำนวนเงินที่ต้องการเตรียมไว้ใช้ในแต่ละเดือนสำหรับหมวดนี้',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                if (existingSubCat == null) ...[
                  DropdownButtonFormField<String>(
                    value: selectedSubCatId,
                    decoration: const InputDecoration(
                      labelText: 'เลือกหมวดหมู่ย่อย',
                      border: OutlineInputBorder(),
                    ),
                    items: availableSubCats.map((s) {
                      final main = mainCats.firstWhere(
                        (m) => m.id == s.mainCategoryId,
                        orElse: () => MainCategory(
                          id: '',
                          name: 'หมวดหลัก',
                          emoji: '📁',
                          color: '#1E88E5',
                          order: 0,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );
                      return DropdownMenuItem<String>(
                        value: s.id,
                        child: Row(
                          children: [
                            Text(s.emoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text('${s.name} (${main.name})', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedSubCatId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'จำนวนเงินเตรียมไว้ (บาท/เดือน)',
                    hintText: 'เช่น 3,000',
                    prefixText: '฿ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text.trim().replaceAll(',', ''));
                  if (amount != null && amount > 0) {
                    final roomId = ref.read(coupleRoomIdProvider);
                    if (roomId != null) {
                      await ref.read(coupleRepositoryProvider).setSubcategoryBudget(roomId, selectedSubCatId, amount);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✨ บันทึกการเตรียมเงิน ${CurrencyFormatter.format(amount)} เรียบร้อย')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final budgets = ref.watch(subcategoryBudgetsProvider);
    final subCats = ref.watch(subCategoriesProvider);
    final transactions = ref.watch(filteredTransactionsProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final monthName = DateFormatter.formatSmartMonth(filters.selectedMonth);

    // Calculate actual spending per subcategory
    final Map<String, double> subCatSpending = {};
    for (var tx in transactions) {
      if (tx.type == 'expense' && tx.subCategoryId.isNotEmpty) {
        subCatSpending[tx.subCategoryId] = (subCatSpending[tx.subCategoryId] ?? 0.0) + tx.amount;
      }
    }

    // Totals
    double totalBudget = 0;
    double totalSpentInBudgetedCats = 0;
    for (var entry in budgets.entries) {
      totalBudget += entry.value;
      totalSpentInBudgetedCats += (subCatSpending[entry.key] ?? 0.0);
    }
    final remainingBudget = totalBudget - totalSpentInBudgetedCats;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Pull Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Title Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.teal.withOpacity(0.2) : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.account_balance_wallet, color: Colors.teal.shade700, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'แผนเตรียมเงินประจำเดือน 📋',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'จัดสรรเงินเดือน & คุมรายจ่าย ($monthName)',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.55)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                      tooltip: 'เพิ่มหมวดเตรียมเงิน',
                      onPressed: () => _showAddOrEditBudgetDialog(),
                    ),
                  ],
                ),
              ),

              // Summary Card (Planned vs Spent vs Remaining)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E2638), const Color(0xFF161E2E)]
                          : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.indigo.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatColumn('เตรียมไว้ทั้งหมด', CurrencyFormatter.format(totalBudget), Colors.indigo.shade700, isDark),
                          Container(width: 1, height: 36, color: Colors.grey.withOpacity(0.2)),
                          _buildStatColumn('ใช้จริงแล้ว', CurrencyFormatter.format(totalSpentInBudgetedCats), AppColors.expense, isDark),
                          Container(width: 1, height: 36, color: Colors.grey.withOpacity(0.2)),
                          _buildStatColumn(
                            'เงินคงเหลือ',
                            CurrencyFormatter.format(remainingBudget),
                            remainingBudget >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            isDark,
                          ),
                        ],
                      ),
                      if (totalBudget > 0) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (totalSpentInBudgetedCats / totalBudget).clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: Colors.white.withOpacity(0.5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              totalSpentInBudgetedCats > totalBudget ? Colors.red : Colors.indigo.shade600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // List of Budgeted Items
              Expanded(
                child: budgets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('ยังไม่ได้ตั้งงบเตรียมเงินประจำเดือน', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showAddOrEditBudgetDialog(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('เริ่มวางแผนเตรียมเงินกองแรก (เช่น ค่ากิน, ค่าน้ำมัน)'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: budgets.entries.length,
                        itemBuilder: (context, index) {
                          final entry = budgets.entries.elementAt(index);
                          final subCatId = entry.key;
                          final planned = entry.value;
                          final spent = subCatSpending[subCatId] ?? 0.0;
                          final ratio = planned > 0 ? (spent / planned) : 0.0;

                          final subCat = subCats.firstWhere(
                            (s) => s.id == subCatId,
                            orElse: () => SubCategory(id: subCatId, mainCategoryId: '', name: 'หมวดย่อย', emoji: '🏷️', color: '#E91E63', order: 0),
                          );

                          final isOver = spent > planned;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isOver ? Colors.red.shade300 : theme.colorScheme.outlineVariant.withOpacity(0.6),
                                width: isOver ? 1.2 : 0.8,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(subCat.emoji, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        subCat.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      isOver
                                          ? '⚠️ เกินงบ +${CurrencyFormatter.format(spent - planned)}'
                                          : 'เหลือ ฿${CurrencyFormatter.format(planned - spent)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isOver ? Colors.red.shade700 : Colors.green.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      color: Colors.grey,
                                      onPressed: () => _showAddOrEditBudgetDialog(
                                        existingSubCat: subCat,
                                        existingBudget: planned,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: ratio.clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: Colors.grey.withOpacity(0.12),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isOver ? Colors.red : (ratio >= 0.8 ? Colors.amber.shade700 : Colors.green.shade600),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ใช้ไป: ${CurrencyFormatter.format(spent)}',
                                      style: TextStyle(fontSize: 10.5, color: isOver ? Colors.red : theme.colorScheme.onSurface.withOpacity(0.6)),
                                    ),
                                    Text(
                                      'เตรียมไว้: ${CurrencyFormatter.format(planned)}',
                                      style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
