import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,##0.00', 'th_TH');
  static final NumberFormat _compactFormatter = NumberFormat.compact(locale: 'th_TH');
  static final NumberFormat _integerFormatter = NumberFormat('#,##0', 'th_TH');

  static String format(double amount, {bool showSign = false, bool isIncome = false}) {
    final formatted = _formatter.format(amount.abs());
    if (showSign) {
      if (isIncome || amount > 0) {
        return '+$formatted ฿';
      } else if (amount < 0) {
        return '-$formatted ฿';
      }
    }
    if (amount < 0) {
      return '-$formatted ฿';
    }
    return '$formatted ฿';
  }

  static String formatNoSymbol(double amount) {
    return _formatter.format(amount);
  }

  static String formatInteger(double amount) {
    return '${_integerFormatter.format(amount)} ฿';
  }

  static String formatCompact(double amount) {
    return '${_compactFormatter.format(amount)} ฿';
  }
}
