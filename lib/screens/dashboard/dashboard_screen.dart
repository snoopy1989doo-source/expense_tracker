import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/report_provider.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/wallet/wallet_card.dart';
import '../../widgets/transaction/transaction_tile.dart';
import '../../widgets/common/empty_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../services/ai_finance_service.dart';
import '../../widgets/ai/ai_chat_dialog.dart';
import '../../widgets/couple/couple_quests_widget.dart';
import '../../widgets/couple/food_decision_wheel_dialog.dart';
import '../../widgets/couple/couple_savings_widget.dart';
import '../../widgets/couple/couple_calendar_dialog.dart';
import '../../models/transaction_item.dart';
import '../transaction/add_edit_transaction_screen.dart';

class DashboardScreen extends ConsumerWidget {
  final VoidCallback onNavigateToTransactions;

  const DashboardScreen({super.key, required this.onNavigateToTransactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);
    final recentTransactions = ref.watch(rawTransactionsProvider).take(5).toList();
    final report = ref.watch(reportProvider);
    final filters = ref.watch(transactionFiltersProvider);
    final filterNotifier = ref.read(transactionFiltersProvider.notifier);

    final mainCats = ref.watch(mainCategoriesProvider);
    final subCats = ref.watch(subCategoriesProvider);

    final mainCatMap = {for (var c in mainCats) c.id: c};
    final subCatMap = {for (var c in subCats) c.id: c};
    final walletMap = {for (var w in wallets) w.id: w};

    final theme = Theme.of(context);

    // Sum total balance across all wallets
    final totalAssets = wallets.fold<double>(0, (sum, w) => sum + w.currentBalance);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Trigger refresh on all providers
            ref.read(rawWalletsProvider.notifier).loadWallets();
            ref.read(rawTransactionsProvider.notifier).loadTransactions();
            ref.read(mainCategoriesProvider.notifier).loadCategories();
            ref.read(subCategoriesProvider.notifier).loadSubCategories();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Greetings & Month selector)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'สวัสดีครับ',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        const Text(
                          'ภาพรวมการเงิน',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // Month controller
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 20),
                            onPressed: () => filterNotifier.previousMonth(),
                          ),
                          Text(
                            DateFormatter.formatSmartMonth(filters.selectedMonth),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            onPressed: () => filterNotifier.nextMonth(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Asset card (Net Wealth)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ยอดเงินคงเหลือรวมทุกบัญชี',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(totalAssets),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Income / Expense Stats
                Row(
                  children: [
                    StatCard(
                      title: 'รายรับเดือนนี้',
                      amount: report.totalIncome,
                      color: AppColors.income,
                      backgroundColor: AppColors.incomeLight.withOpacity(0.4),
                      icon: Icons.arrow_upward,
                    ),
                    const SizedBox(width: 14),
                    StatCard(
                      title: 'รายจ่ายเดือนนี้',
                      amount: report.totalExpense,
                      color: AppColors.expense,
                      backgroundColor: AppColors.expenseLight.withOpacity(0.4),
                      icon: Icons.arrow_downward,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // AI Smart Insights & Predictor Card
                _buildAIPredictorCard(context, ref, ref.watch(rawTransactionsProvider)),
                const SizedBox(height: 16),

                // Quick Couple Gimmick Buttons Row (AI Chat, Food Decision Wheel, Memory Calendar)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => AIChatDialog.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.pink.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                              SizedBox(width: 4),
                              Text('ถาม AI 🤖', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => FoodDecisionWheelDialog.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.casino, color: Colors.orange, size: 16),
                              SizedBox(width: 4),
                              Text('กินอะไรดี? 🎰', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => CoupleCalendarDialog.show(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.purple.shade300),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_month, color: Colors.purple, size: 16),
                              SizedBox(width: 4),
                              Text('ปฏิทินรัก 📅', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Couple Shared Savings Pot Widget (🐷)
                const CoupleSavingsWidget(),
                const SizedBox(height: 20),

                // Couple Quests & Horoscope Card
                const CoupleQuestsWidget(),
                const SizedBox(height: 20),

                // Horizontal Wallets List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'กระเป๋าเงิน / บัญชี',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 20),
                      onPressed: () {
                        // We will let the parent screen navigate to Wallets management tab
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (wallets.isEmpty)
                  const Center(child: Text('ไม่มีบัญชีผู้ใช้'))
                else
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: wallets.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final wallet = wallets[index];
                        return WalletCard(
                          wallet: wallet,
                          onTap: () {
                            filterNotifier.setWallet(wallet.id);
                            onNavigateToTransactions();
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 28),

                // Recent Transactions List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ธุรกรรมล่าสุด',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: onNavigateToTransactions,
                      child: const Text('ดูทั้งหมด'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (recentTransactions.isEmpty)
                  EmptyState(
                    title: 'ยังไม่มีประวัติการบันทึก',
                    description: 'กดปุ่ม + ด้านล่างเพื่อเริ่มสร้างรายการรายรับหรือรายจ่ายแรกของคุณ',
                    onButtonPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddEditTransactionScreen()),
                      );
                    },
                    buttonText: 'บันทึกรายการแรก',
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentTransactions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final tx = recentTransactions[index];
                      final mainCat = mainCatMap[tx.mainCategoryId];
                      final subCat = subCatMap[tx.subCategoryId];
                      final wallet = walletMap[tx.walletId];
                      
                      return TransactionTile(
                        transaction: tx,
                        mainCategory: mainCat,
                        subCategory: subCat,
                        wallet: wallet,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEditTransactionScreen(transaction: tx),
                            ),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 80), // Padding to avoid FAB overlay
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEditTransactionScreen()),
          );
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildAIPredictorCard(BuildContext context, WidgetRef ref, List<TransactionItem> transactions) {
    final theme = Theme.of(context);
    final predictions = AIFinanceService.predictUpcomingExpenses(transactions);
    final topPrediction = predictions.first;

    return Card(
      color: theme.colorScheme.primaryContainer.withOpacity(0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(topPrediction.iconEmoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'AI Smart Insights',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () => AIChatDialog.show(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('ถาม AI', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topPrediction.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              topPrediction.description,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
