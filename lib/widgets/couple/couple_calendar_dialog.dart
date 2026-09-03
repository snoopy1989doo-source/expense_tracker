import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/transaction_item.dart';

class CoupleCalendarDialog extends ConsumerStatefulWidget {
  const CoupleCalendarDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CoupleCalendarDialog(),
    );
  }

  @override
  ConsumerState<CoupleCalendarDialog> createState() => _CoupleCalendarDialogState();
}

class _CoupleCalendarDialogState extends ConsumerState<CoupleCalendarDialog> {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(rawTransactionsProvider);
    final mainCats = ref.watch(mainCategoriesProvider);
    final theme = Theme.of(context);

    // Map transactions by YYYY-MM-DD
    final Map<String, List<TransactionItem>> dateTxMap = {};
    for (var tx in transactions) {
      final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
      dateTxMap.putIfAbsent(key, () => []).add(tx);
    }

    final selectedKey = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final selectedDayTransactions = dateTxMap[selectedKey] ?? [];

    // Calculate days in month
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7; // 0 = Sun

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_month, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📅 ปฏิทินความทรงจำการเงินคู่รัก',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'ปักหมุดบันทึกรัก & ย้อนดูความทรงจำเดตรายวัน',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Month navigation header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                    });
                  },
                ),
                Text(
                  DateFormatter.formatSmartMonth(_focusedMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Weekday labels
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('อา', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                Text('จ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text('อ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text('พ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text('พฤ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text('ศ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text('ส', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 8),

            // Grid calendar days
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.1,
              ),
              itemCount: firstWeekday + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday) {
                  return const SizedBox();
                }
                final dayNum = index - firstWeekday + 1;
                final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
                final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final txs = dateTxMap[dateKey] ?? [];
                final hasLoveNote = txs.any((t) => t.loveNote != null && t.loveNote!.isNotEmpty);
                final isSelected = _selectedDate.year == date.year && _selectedDate.month == date.month && _selectedDate.day == date.day;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (txs.isNotEmpty ? theme.colorScheme.primary.withOpacity(0.08) : Colors.transparent),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : (hasLoveNote ? Colors.pink.shade300 : Colors.transparent),
                        width: hasLoveNote ? 1.5 : 1,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (hasLoveNote)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Icon(Icons.favorite, size: 8, color: isSelected ? Colors.white : AppColors.primary),
                          )
                        else if (txs.isNotEmpty)
                          Positioned(
                            bottom: 3,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 20),

            // Selected date transaction list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ความทรงจำวันที่ ${DateFormatter.formatDayMonthYear(_selectedDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${selectedDayTransactions.length} รายการ',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 140,
              child: selectedDayTransactions.isEmpty
                  ? const Center(
                      child: Text(
                        'ไม่มีรายการใช้จ่ายหรือ Love Note ในวันนี้ 🌸',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: selectedDayTransactions.length,
                      itemBuilder: (context, index) {
                        final tx = selectedDayTransactions[index];
                        final mainCat = mainCats.firstWhere(
                          (c) => c.id == tx.mainCategoryId,
                          orElse: () => mainCats.first,
                        );

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Text(mainCat.emoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.note?.isNotEmpty == true ? tx.note! : mainCat.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    if (tx.loveNote != null && tx.loveNote!.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.favorite, size: 10, color: AppColors.primary),
                                          const SizedBox(width: 2),
                                          Text(
                                            tx.loveNote!,
                                            style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(tx.amount, showSign: true, isIncome: tx.type == 'income'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: tx.type == 'income' ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
