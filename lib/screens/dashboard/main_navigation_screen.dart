import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import '../transaction/transaction_list_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/transaction_item.dart';
import '../../core/utils/currency_formatter.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  final Set<String> _knownTxIds = {};
  bool _isFirstLoad = true;

  void _navigateToTransactions() {
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authStateProvider).value;

    // Listen to real-time transactions stream for partner notifications
    ref.listen<List<TransactionItem>>(rawTransactionsProvider, (previous, next) {
      if (_isFirstLoad) {
        _knownTxIds.addAll(next.map((t) => t.id));
        if (next.isNotEmpty) {
          _isFirstLoad = false;
        }
        return;
      }

      final prevIds = previous?.map((t) => t.id).toSet() ?? <String>{};
      final newTxs = next.where((t) => !prevIds.contains(t.id) && !_knownTxIds.contains(t.id)).toList();

      for (var tx in newTxs) {
        _knownTxIds.add(tx.id);

        // Only notify if the transaction is recent (created within the last 5 minutes)
        final age = DateTime.now().difference(tx.createdAt).inMinutes.abs();
        if (age > 5) continue;

        // If transaction was created by partner
        if (tx.createdByUserId != null && tx.createdByUserId != currentUserId) {
          final partnerName = tx.createdByName ?? 'แฟนของคุณ';
          final typeText = tx.type == 'income' ? 'รายรับ' : 'รายจ่าย';
          final amountText = CurrencyFormatter.format(tx.amount);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Text('💕 ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      '[$partnerName] บันทึก$typeTextใหม่ $amountText ${tx.note != null ? "(${tx.note})" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFE91E63),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    });

    final List<Widget> screens = [
      DashboardScreen(onNavigateToTransactions: _navigateToTransactions),
      const TransactionListScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'แดชบอร์ด',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'รายการ',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'รายงาน',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'ตั้งค่า',
          ),
        ],
      ),
    );
  }
}
