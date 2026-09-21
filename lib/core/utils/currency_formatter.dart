class CurrencyFormatter {
  const CurrencyFormatter._();

  static String formatIDR(int amount) {
    final sign = amount < 0 ? '-' : '';
    final digits = amount.abs().toString();
    final buffer = StringBuffer(sign);
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) buffer.write('.');
    }
    return 'Rp $buffer';
  }
}