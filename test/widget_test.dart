import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:expense_tracker/core/utils/currency_formatter.dart';
import 'package:expense_tracker/core/utils/date_formatter.dart';
import 'package:expense_tracker/models/transaction_item.dart';
import 'package:expense_tracker/models/savings_goal.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH', null);
  });
  group('CurrencyFormatter Tests', () {
    test('formats positive amounts correctly', () {
      expect(CurrencyFormatter.format(1250.0), '1,250.00 ฿');
      expect(CurrencyFormatter.format(0.0), '0.00 ฿');
      expect(CurrencyFormatter.format(1000000.5), '1,000,000.50 ฿');
    });

    test('formats with showSign correctly', () {
      expect(CurrencyFormatter.format(500.0, showSign: true, isIncome: true), '+500.00 ฿');
      expect(CurrencyFormatter.format(250.0, showSign: true, isIncome: false), '+250.00 ฿');
      expect(CurrencyFormatter.format(-300.0, showSign: true), '-300.00 ฿');
    });

    test('formats compact and integer correctly', () {
      expect(CurrencyFormatter.formatInteger(1500.99), '1,501 ฿');
      expect(CurrencyFormatter.formatNoSymbol(1250.5), '1,250.50');
    });
  });

  group('DateFormatter Tests', () {
    test('formats smart month in Thai correctly', () {
      final jan2026 = DateTime(2026, 1, 15);
      final formatted = DateFormatter.formatSmartMonth(jan2026);
      expect(formatted.contains('มกราคม') || formatted.contains('ม.ค.'), isTrue);
    });

    test('formats time in Thai format', () {
      final dt = DateTime(2026, 9, 4, 14, 30);
      final timeStr = DateFormatter.formatTime(dt);
      expect(timeStr, '14:30 น.');
    });
  });

  group('TransactionItem Model Tests', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime(2026, 9, 4, 10, 0);
      final item = TransactionItem(
        id: 'tx-123',
        type: 'expense',
        amount: 350.0,
        date: now,
        mainCategoryId: 'food',
        subCategoryId: 'lunch',
        walletId: 'wallet-kbank',
        note: 'ส้มตำแซ่บๆ กับแฟน',
        loveNote: 'อร่อยมากกกก 💕',
        isTaxDeductible: false,
        createdByUserId: 'user-dooodo',
        createdByName: 'ต๋อง',
        createdAt: now,
        updatedAt: now,
      );

      final map = item.toMap();
      expect(map['id'], 'tx-123');
      expect(map['type'], 'expense');
      expect(map['amount'], 350.0);
      expect(map['note'], 'ส้มตำแซ่บๆ กับแฟน');
      expect(map['loveNote'], 'อร่อยมากกกก 💕');
      expect(map['createdByName'], 'ต๋อง');

      final fromMap = TransactionItem.fromMap(map, 'tx-123');
      expect(fromMap.id, 'tx-123');
      expect(fromMap.amount, 350.0);
      expect(fromMap.note, 'ส้มตำแซ่บๆ กับแฟน');
      expect(fromMap.loveNote, 'อร่อยมากกกก 💕');
    });
  });

  group('SavingsGoal Calculation Tests', () {
    test('calculates progress percentage and remaining correctly', () {
      final goal = SavingsGoal(
        id: 'goal-japan',
        title: 'ทริปเที่ยวญี่ปุ่นปลายปี',
        targetAmount: 50000.0,
        currentAmount: 25000.0,
        emoji: '✈️',
        targetDate: DateTime(2026, 12, 31),
        createdAt: DateTime.now(),
      );

      expect(goal.progressPercentage, 50.0);
      expect(goal.isCompleted, isFalse);

      final completedGoal = goal.copyWith(currentAmount: 50000.0);
      expect(completedGoal.progressPercentage, 100.0);
      expect(completedGoal.isCompleted, isTrue);
    });
  });

  group('Slip & Bill Calculator Expression Parser Tests', () {
    double evalExpression(String expr) {
      expr = expr.replaceAll(' ', '').replaceAll(',', '').replaceAll('×', '*').replaceAll('÷', '/');
      final parts = expr.split(RegExp(r'(?<=[+-])|(?=[+-])'));
      double total = 0;
      String currentOp = '+';

      double evalMultDiv(String term) {
        final factors = term.split(RegExp(r'(?<=[*/])|(?=[*/])'));
        double subtotal = double.tryParse(factors[0]) ?? 0;
        String op = '*';

        for (int i = 1; i < factors.length; i++) {
          final f = factors[i];
          if (f == '*' || f == '/') {
            op = f;
          } else {
            final val = double.tryParse(f) ?? 1;
            if (op == '*') subtotal *= val;
            if (op == '/') subtotal = val != 0 ? subtotal / val : subtotal;
          }
        }
        return subtotal;
      }

      for (var part in parts) {
        if (part == '+' || part == '-') {
          currentOp = part;
        } else {
          double termVal = evalMultDiv(part);
          if (currentOp == '+') total += termVal;
          if (currentOp == '-') total -= termVal;
        }
      }
      return total;
    }

    test('handles standard arithmetic', () {
      expect(evalExpression('100 + 50'), 150.0);
      expect(evalExpression('200 - 45'), 155.0);
      expect(evalExpression('50 × 4'), 200.0);
      expect(evalExpression('300 ÷ 3'), 100.0);
    });

    test('handles comma in numbers without crashing', () {
      expect(evalExpression('1,500.50 + 2,499.50'), 4000.0);
      expect(evalExpression('10,000 ÷ 2'), 5000.0);
    });
  });
}
