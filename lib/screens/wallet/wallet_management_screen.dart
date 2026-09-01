import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/confirm_dialog.dart';
import '../../widgets/category/color_picker_dialog.dart';

class WalletManagementScreen extends ConsumerStatefulWidget {
  const WalletManagementScreen({super.key});

  @override
  ConsumerState<WalletManagementScreen> createState() => _WalletManagementScreenState();
}

class _WalletManagementScreenState extends ConsumerState<WalletManagementScreen> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  Color _dialogColor = AppColors.categoryPalette.first;
  String _selectedIcon = 'account_balance_wallet';

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _showAddEditWalletDialog([Wallet? existing]) {
    _nameController.text = existing?.name ?? '';
    _balanceController.text = existing != null ? existing.currentBalance.toStringAsFixed(2) : '0.00';
    _dialogColor = existing != null ? AppColors.fromHex(existing.color) : AppColors.categoryPalette.first;
    _selectedIcon = existing?.icon ?? 'account_balance_wallet';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'เพิ่มกระเป๋าเงิน / บัญชี' : 'แก้ไขกระเป๋าเงิน'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อบัญชี / กระเป๋าเงิน',
                    hintText: 'เช่น เงินสด, บัญชีกสิกรไทย',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: existing == null ? 'ยอดเงินเริ่มต้น (บาท)' : 'ยอดเงินคงเหลือปัจจุบัน (บาท)',
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedIcon,
                  decoration: const InputDecoration(labelText: 'สัญลักษณ์'),
                  items: const [
                    DropdownMenuItem(value: 'account_balance_wallet', child: Row(children: [Icon(Icons.account_balance_wallet), SizedBox(width: 8), Text('กระเป๋าเงิน')])),
                    DropdownMenuItem(value: 'account_balance', child: Row(children: [Icon(Icons.account_balance), SizedBox(width: 8), Text('ธนาคาร')])),
                    DropdownMenuItem(value: 'payments', child: Row(children: [Icon(Icons.payments), SizedBox(width: 8), Text('เงินสด')])),
                    DropdownMenuItem(value: 'credit_card', child: Row(children: [Icon(Icons.credit_card), SizedBox(width: 8), Text('บัตรเครดิต')])),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => _selectedIcon = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('สีสัญลักษณ์: '),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => ColorPickerDialog.show(context, (color) {
                        setDialogState(() => _dialogColor = color);
                      }),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: _dialogColor, shape: BoxShape.circle),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.trim().isNotEmpty) {
                  final walletList = ref.read(walletsProvider);
                  final inputBalance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
                  final double startingBalance;
                  if (existing == null) {
                    startingBalance = inputBalance;
                  } else {
                    final diff = inputBalance - existing.currentBalance;
                    startingBalance = existing.startingBalance + diff;
                  }

                  final wallet = Wallet(
                    id: existing?.id ?? 'wallet_${const Uuid().v4()}',
                    name: _nameController.text.trim(),
                    color: AppColors.toHex(_dialogColor),
                    icon: _selectedIcon,
                    startingBalance: startingBalance,
                    currentBalance: inputBalance,
                    order: existing?.order ?? walletList.length,
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  );
                  if (existing == null) {
                    ref.read(rawWalletsProvider.notifier).addWallet(wallet);
                  } else {
                    ref.read(rawWalletsProvider.notifier).updateWallet(wallet);
                  }
                  Navigator.of(context).pop();
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteWallet(Wallet wallet) {
    ConfirmDialog.show(
      context,
      title: 'ลบกระเป๋าเงิน',
      content: 'คุณแน่ใจว่าต้องการลบกระเป๋าเงิน "${wallet.name}" หรือไม่?\n⚠️ การลบกระเป๋าเงินจะไม่ทำการลบประวัติธุรกรรมที่บันทึกไว้ แต่อาจส่งผลให้ยอดคงเหลือรวมคำนวณไม่ถูกต้อง',
      confirmText: 'ลบข้อมูล',
      confirmColor: AppColors.expense,
      onConfirm: () {
        ref.read(rawWalletsProvider.notifier).deleteWallet(wallet.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider);

    IconData getIcon(String iconName) {
      switch (iconName) {
        case 'account_balance':
          return Icons.account_balance;
        case 'payments':
          return Icons.payments;
        case 'credit_card':
          return Icons.credit_card;
        case 'account_balance_wallet':
        default:
          return Icons.account_balance_wallet;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('กระเป๋าเงิน & บัญชี'),
      ),
      body: wallets.isEmpty
          ? const Center(child: Text('ไม่มีกระเป๋าเงิน กดปุ่ม + เพื่อเพิ่ม'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: wallets.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final List<Wallet> reorderedList = List<Wallet>.from(wallets);
                final item = reorderedList.removeAt(oldIndex);
                reorderedList.insert(newIndex, item);
                ref.read(rawWalletsProvider.notifier).reorderWallets(reorderedList);
              },
              itemBuilder: (context, index) {
                final wallet = wallets[index];
                final wColor = AppColors.fromHex(wallet.color);

                return Card(
                  key: ValueKey(wallet.id),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: wColor.withOpacity(0.12),
                      child: Icon(getIcon(wallet.icon), color: wColor),
                    ),
                    title: Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ยอดตั้งต้น: ${wallet.startingBalance.toStringAsFixed(2)} ฿'),
                        Text(
                          'ยอดปัจจุบัน: ${wallet.currentBalance.toStringAsFixed(2)} ฿',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: wallet.currentBalance >= 0 ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showAddEditWalletDialog(wallet),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.expense, size: 20),
                          onPressed: () => _confirmDeleteWallet(wallet),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.drag_handle, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditWalletDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
