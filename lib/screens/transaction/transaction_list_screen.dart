import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/transaction/transaction_tile.dart';
import '../../widgets/common/empty_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import 'add_edit_transaction_screen.dart';

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredTransactions = ref.watch(filteredTransactionsProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final filterNotifier = ref.read(transactionFiltersProvider.notifier);

    final wallets = ref.watch(walletsProvider);
    final mainCats = ref.watch(mainCategoriesProvider);
    final subCats = ref.watch(subCategoriesProvider);

    final mainCatMap = {for (var c in mainCats) c.id: c};
    final subCatMap = {for (var c in subCats) c.id: c};
    final walletMap = {for (var w in wallets) w.id: w};

    final theme = Theme.of(context);

    // Group filtered transactions by date
    final Map<String, List<dynamic>> groupedTransactions = {};
    for (var tx in filteredTransactions) {
      final dateKey = DateFormatter.formatDayMonthYear(tx.date);
      if (groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey]!.add(tx);
      } else {
        groupedTransactions[dateKey] = [tx];
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการธุรกรรมทั้งหมด'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(115),
          child: Column(
            children: [
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ค้นหาด้วยคำสำคัญ หรือจำนวนเงิน...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    fillColor: theme.brightness == Brightness.light ? Colors.grey.shade100 : const Color(0xFF1E1E1E),
                    suffixIcon: filters.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => filterNotifier.setSearchQuery(''),
                          )
                        : null,
                  ),
                  onChanged: (val) => filterNotifier.setSearchQuery(val),
                ),
              ),
              
              // Filter badges horizontal scroll list
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    // Type filter dropdown / popup menu
                    PopupMenuButton<String?>(
                      initialValue: filters.selectedType,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: filters.selectedType != null ? theme.colorScheme.primaryContainer : Colors.transparent,
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              filters.selectedType == 'income'
                                  ? 'ประเภท: รายรับ'
                                  : (filters.selectedType == 'expense' ? 'ประเภท: รายจ่าย' : 'ทุกประเภท'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: filters.selectedType != null ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
                      onSelected: (val) => filterNotifier.setType(val),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: null, child: Text('ทุกประเภท')),
                        PopupMenuItem(value: 'income', child: Text('รายรับเท่านั้น')),
                        PopupMenuItem(value: 'expense', child: Text('รายจ่ายเท่านั้น')),
                      ],
                    ),
                    const SizedBox(width: 8),

                    // Wallet filter popup
                    PopupMenuButton<String?>(
                      initialValue: filters.selectedWalletId,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: filters.selectedWalletId != null ? theme.colorScheme.primaryContainer : Colors.transparent,
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              filters.selectedWalletId != null
                                  ? 'กระเป๋า: ${walletMap[filters.selectedWalletId]?.name}'
                                  : 'ทุกกระเป๋าเงิน',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: filters.selectedWalletId != null ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
                      onSelected: (val) => filterNotifier.setWallet(val),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: null, child: Text('ทุกกระเป๋าเงิน')),
                        ...wallets.map((w) => PopupMenuItem(value: w.id, child: Text(w.name))),
                      ],
                    ),
                    const SizedBox(width: 8),

                    // Category filter popup
                    PopupMenuButton<String?>(
                      initialValue: filters.selectedMainCategoryId,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: filters.selectedMainCategoryId != null ? theme.colorScheme.primaryContainer : Colors.transparent,
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              filters.selectedMainCategoryId != null
                                  ? 'หมวดหมู่: ${mainCatMap[filters.selectedMainCategoryId]?.name.split(' (')[0]}'
                                  : 'ทุกหมวดหมู่',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: filters.selectedMainCategoryId != null ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
                      onSelected: (val) => filterNotifier.setMainCategory(val),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: null, child: Text('ทุกหมวดหมู่')),
                        ...mainCats.map((c) => PopupMenuItem(value: c.id, child: Text(c.name))),
                      ],
                    ),
                    const SizedBox(width: 8),

                    // Tax-deductible toggle badge
                    FilterChip(
                      label: const Row(
                        children: [
                          Icon(Icons.gavel, size: 14, color: AppColors.taxDeductible),
                          SizedBox(width: 4),
                          Text('ลดหย่อนภาษี', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      selected: filters.onlyTaxDeductible == true,
                      onSelected: (val) => filterNotifier.toggleTaxDeductible(val ? true : null),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: filteredTransactions.isEmpty
          ? EmptyState(
              title: 'ไม่พบรายการธุรกรรม',
              description: 'ไม่พบรายการในช่วงเวลานี้ หรือผลลัพธ์ที่ตรงกับตัวกรองของคุณ',
              onButtonPressed: () => filterNotifier.resetFilters(),
              buttonText: 'ล้างตัวกรองทั้งหมด',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: groupedTransactions.keys.length,
              itemBuilder: (context, index) {
                final dateKey = groupedTransactions.keys.elementAt(index);
                final list = groupedTransactions[dateKey]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 12.0, bottom: 8.0),
                      child: Text(
                        dateKey,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                    ...list.map((tx) => TransactionTile(
                          transaction: tx,
                          mainCategory: mainCatMap[tx.mainCategoryId],
                          subCategory: subCatMap[tx.subCategoryId],
                          wallet: walletMap[tx.walletId],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddEditTransactionScreen(transaction: tx),
                              ),
                            );
                          },
                        )),
                  ],
                );
              },
            ),
    );
  }
}
