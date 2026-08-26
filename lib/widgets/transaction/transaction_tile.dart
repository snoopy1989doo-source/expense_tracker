import 'package:flutter/material.dart';
import '../../models/transaction_item.dart';
import '../../models/main_category.dart';
import '../../models/sub_category.dart';
import '../../models/wallet.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import 'receipt_preview_dialog.dart';

class TransactionTile extends StatelessWidget {
  final TransactionItem transaction;
  final MainCategory? mainCategory;
  final SubCategory? subCategory;
  final Wallet? wallet;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.mainCategory,
    this.subCategory,
    this.wallet,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    final catColor = AppColors.fromHex(mainCategory?.color ?? '#9E9E9E');

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: catColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            subCategory?.emoji ?? mainCategory?.emoji ?? '📁',
            style: const TextStyle(fontSize: 22),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                transaction.note?.isNotEmpty == true
                    ? transaction.note!
                    : (subCategory?.name ?? mainCategory?.name ?? 'ไม่ระบุ'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CurrencyFormatter.format(transaction.amount, showSign: true, isIncome: isIncome),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: amountColor,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.fromHex(wallet?.color ?? '#9E9E9E').withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      wallet?.name ?? 'ไม่มีกระเป๋า',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.fromHex(wallet?.color ?? '#9E9E9E'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (transaction.createdByName != null && transaction.createdByName!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, size: 10, color: AppColors.primary),
                          const SizedBox(width: 2),
                          Text(
                            transaction.createdByName!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (transaction.isTaxDeductible)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.taxDeductibleLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gavel, color: AppColors.taxDeductible, size: 10),
                          SizedBox(width: 2),
                          Text(
                            'ลดหย่อนภาษี',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.taxDeductible,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (transaction.receiptImageUrl != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => ReceiptPreviewDialog.show(context, transaction.receiptImageUrl!),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.receipt_long, size: 12, color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                DateFormatter.formatTime(transaction.date),
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
