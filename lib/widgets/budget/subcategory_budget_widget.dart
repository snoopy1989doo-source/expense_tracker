import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/sub_category.dart';
import '../../models/main_category.dart';
import '../../providers/category_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/transaction_provider.dart';

class SubcategoryBudgetWidget extends ConsumerStatefulWidget {
  const SubcategoryBudgetWidget({super.key});

  @override
  ConsumerState<SubcategoryBudgetWidget> createState() => _SubcategoryBudgetWidgetState();
}

class _SubcategoryBudgetWidgetState extends ConsumerState<SubcategoryBudgetWidget> {
  void _showAddOrEditBudgetDialog({SubCategory? existingSubCat, double? existingBudget}) {
    final subCats = ref.read(subCategoriesProvider);
    final mainCats = ref.read(mainCategoriesProvider);
    final currentBudgets = ref.read(subcategoryBudgetsProvider);

    // If adding, filter out already budgeted subcategories
    final availableSubCats = existingSubCat != null
        ? subCats
        : subCats.where((s) => !currentBudgets.containsKey(s.id)).toList();

    if (availableSubCats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณได้ตั้งงบประมาณให้กับหมวดย่อยทั้งหมดเรียบร้อยแล้ว')),
      );
      return;
    }

    String? selectedSubCatId = existingSubCat?.id ?? availableSubCats.first.id;
    final amountController = TextEditingController(
      text: existingBudget != null ? existingBudget.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final chosenSubCat = subCats.firstWhere(
            (s) => s.id == selectedSubCatId,
            orElse: () => subCats.first,
          );
          final parentMainCat = mainCats.firstWhere(
            (m) => m.id == chosenSubCat.mainCategoryId,
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

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.track_changes, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  existingSubCat != null ? '✏️ แก้ไขงบหมวดย่อย' : '🎯 ตั้งงบหมวดย่อยพิเศษ',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'เลือกหมวดย่อยที่คุณและแฟนอยากคุมงบไม่ให้เกินในแต่ละเดือน',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                if (existingSubCat == null) ...[
                  DropdownButtonFormField<String>(
                    value: selectedSubCatId,
                    decoration: const InputDecoration(
                      labelText: 'เลือกหมวดย่อย',
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
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.emoji} ${s.name} (${main.name})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() => selectedSubCatId = val);
                    },
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(chosenSubCat.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(chosenSubCat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('หมวดหลัก: ${parentMainCat.name}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'งบประมาณรายเดือน (฿)',
                    hintText: 'เช่น 1000, 3000',
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
                  final amt = double.tryParse(amountController.text.trim()) ?? 0;
                  if (selectedSubCatId != null && amt > 0) {
                    final roomId = ref.read(coupleRoomIdProvider);
                    if (roomId != null) {
                      await ref.read(coupleRepositoryProvider).setSubcategoryBudget(roomId, selectedSubCatId!, amt);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✨ บันทึกงบ "${chosenSubCat.emoji} ${chosenSubCat.name}" ${CurrencyFormatter.format(amt)}/เดือน สำเร็จ!')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('บันทึกงบ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteBudget(SubCategory subCat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🗑️ ยกเลิกการคุมงบหมวดย่อย', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('คุณแน่ใจว่าต้องการยกเลิกการตั้งงบสำหรับหมวด "${subCat.emoji} ${subCat.name}" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              final roomId = ref.read(coupleRoomIdProvider);
              if (roomId != null) {
                await ref.read(coupleRepositoryProvider).removeSubcategoryBudget(roomId, subCat.id);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('🗑️ ยกเลิกการคุมงบ "${subCat.name}" เรียบร้อยแล้ว')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
            child: const Text('ยกเลิกการคุมงบ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgets = ref.watch(subcategoryBudgetsProvider);
    final subCats = ref.watch(subCategoriesProvider);
    final transactions = ref.watch(rawTransactionsProvider);

    final now = DateTime.now();
    final currentMonthTxs = transactions.where((t) =>
      t.type == 'expense' && t.date.year == now.year && t.date.month == now.month
    ).toList();

    // Map subcategory ID to current month spending sum
    final Map<String, double> subCatSpending = {};
    for (var tx in currentMonthTxs) {
      if (tx.subCategoryId.isNotEmpty) {
        subCatSpending[tx.subCategoryId] = (subCatSpending[tx.subCategoryId] ?? 0.0) + tx.amount;
      }
    }

    final budgetEntries = budgets.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.track_changes, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '🎯 คุมงบหมวดย่อยพิเศษ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.primary),
                  tooltip: 'ตั้งงบหมวดย่อยเพิ่ม',
                  onPressed: () => _showAddOrEditBudgetDialog(),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (budgetEntries.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Text(
                      'ยังไม่ได้ตั้งงบหมวดย่อยที่ต้องการคุมเป็นพิเศษ',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showAddOrEditBudgetDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('ตั้งงบหมวดแรก (เช่น ชานม 🧋, ชาบู 🍲)', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: budgetEntries.map((entry) {
                  final subCatId = entry.key;
                  final targetBudget = entry.value;
                  final spent = subCatSpending[subCatId] ?? 0.0;
                  final ratio = targetBudget > 0 ? (spent / targetBudget) : 0.0;
                  final percentage = (ratio * 100).clamp(0, 999).toDouble();

                  final subCat = subCats.firstWhere(
                    (s) => s.id == subCatId,
                    orElse: () => SubCategory(id: subCatId, mainCategoryId: '', name: 'หมวดย่อย', emoji: '🏷️', color: '#E91E63', order: 0),
                  );

                  // Color scheme based on spending ratio
                  Color barColor;
                  Color badgeBg;
                  Color badgeText;
                  String statusLabel;

                  if (spent > targetBudget) {
                    barColor = Colors.red.shade600;
                    badgeBg = Colors.red.shade50;
                    badgeText = Colors.red.shade800;
                    statusLabel = '⚠️ เกินงบ +${CurrencyFormatter.format(spent - targetBudget)}';
                  } else if (ratio >= 0.7) {
                    barColor = Colors.amber.shade700;
                    badgeBg = Colors.amber.shade50;
                    badgeText = Colors.amber.shade900;
                    statusLabel = '🟡 ใกล้เต็มงบ (${percentage.toStringAsFixed(0)}%)';
                  } else {
                    barColor = Colors.green.shade600;
                    badgeBg = Colors.green.shade50;
                    badgeText = Colors.green.shade800;
                    statusLabel = '🟢 คุมงบได้ดี (${percentage.toStringAsFixed(0)}%)';
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: spent > targetBudget ? Colors.red.shade300 : theme.colorScheme.outlineVariant,
                        width: spent > targetBudget ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(subCat.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                subCat.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeText),
                              ),
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showAddOrEditBudgetDialog(existingSubCat: subCat, existingBudget: targetBudget);
                                } else if (val == 'delete') {
                                  _confirmDeleteBudget(subCat);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 14, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('แก้ไขงบประมาณ ✏️', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 14, color: AppColors.expense),
                                      SizedBox(width: 8),
                                      Text('ยกเลิกการคุมงบ 🗑️', style: TextStyle(fontSize: 12, color: AppColors.expense)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (ratio).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Numerical Math row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ใช้ไป: ${CurrencyFormatter.format(spent)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: spent > targetBudget ? Colors.red.shade700 : AppColors.primary,
                              ),
                            ),
                            Text(
                              'งบ: ${CurrencyFormatter.format(targetBudget)}',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                            ),
                          ],
                        ),

                        // Affectionate Couple Tip Bubble 💌
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: spent > targetBudget
                                ? (theme.brightness == Brightness.dark
                                    ? const Color(0xFF3B1E28)
                                    : const Color(0xFFFFF0F3))
                                : (ratio >= 0.8
                                    ? (theme.brightness == Brightness.dark
                                        ? const Color(0xFF332A1A)
                                        : const Color(0xFFFFFBEB))
                                    : (theme.brightness == Brightness.dark
                                        ? const Color(0xFF162D24)
                                        : const Color(0xFFF0FDF4))),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: spent > targetBudget
                                  ? const Color(0xFFFF6584).withOpacity(0.3)
                                  : (ratio >= 0.8
                                      ? Colors.amber.shade300
                                      : Colors.green.shade200),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spent > targetBudget
                                    ? '🫂'
                                    : (ratio >= 0.8 ? '🍳' : '🌟'),
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  spent > targetBudget
                                      ? 'หมวด ${subCat.name} ทะลุเพดานไปนิด แต่ไม่เป็นไรน้า! เดือนนี้เน้นความสุข เดือนหน้าค่อยกอดคอช่วยกันใหม่นะคนเก่ง 🥰'
                                      : (ratio >= 0.8
                                          ? 'งบ ${subCat.name} เดือนนี้แตะ ${percentage.toStringAsFixed(0)}% แล้วน้า สัปดาห์นี้ชวนกันทำอาหารกินที่บ้านหรือช่วยกันประหยัดหน่อยนะคนดี 💕'
                                          : 'ช่วยกันคุมงบ ${subCat.name} ได้ยอดเยี่ยมมาก แฟนภูมิใจในตัวคุณสุดๆ เลย! ✨'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                    color: spent > targetBudget
                                        ? (theme.brightness == Brightness.dark ? const Color(0xFFFF8DA1) : const Color(0xFFBE123C))
                                        : (ratio >= 0.8
                                            ? (theme.brightness == Brightness.dark ? const Color(0xFFFCD34D) : const Color(0xFFB45309))
                                            : (theme.brightness == Brightness.dark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
