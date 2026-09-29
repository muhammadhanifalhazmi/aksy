import '../../../core/data/app_store.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/order.dart';

enum ReceiptAlign { left, center }

class ReceiptLine {
  const ReceiptLine(this.text, {this.align = ReceiptAlign.left, this.bold = false});

  final String text;
  final ReceiptAlign align;
  final bool bold;
}

int receiptColumns({required bool wide}) => wide ? 48 : 32;

List<ReceiptLine> buildReceiptLines({
  required Order order,
  required AppStore store,
  required int cols,
}) {
  final settings = store.settings;
  final shift = store.activeShift;
  final lines = <ReceiptLine>[];

  void center(String text, {bool bold = false}) {
    if (text.trim().isEmpty) return;
    lines.add(ReceiptLine(fitToWidth(text, cols), align: ReceiptAlign.center, bold: bold));
  }

  void row(String left, String right, {bool bold = false}) {
    lines.add(ReceiptLine(pairColumns(left, right, cols), bold: bold));
  }

  void left(String text, {bool bold = false}) {
    lines.add(ReceiptLine(fitToWidth(text, cols), bold: bold));
  }

  void divider() {
    lines.add(ReceiptLine('-' * cols, align: ReceiptAlign.center));
  }

  center(settings.name, bold: true);
  center(settings.address);
  center(settings.phone);
  center('');
  row('No. ${order.id}', shift?.id ?? '');
  row('Tgl', DateFormatter.when(order.createdAt));
  divider();
  for (final item in order.items) {
    left('${item.quantity} ${item.product.name}', bold: true);
    row(
      '  @${CurrencyFormatter.formatIDR(item.unitPrice)}'
      '${item.isWholesale ? ' (grosir)' : ''}',
      CurrencyFormatter.formatIDR(item.subtotal),
    );
  }
  divider();
  row('Subtotal', CurrencyFormatter.formatIDR(order.itemsTotal));
  row('Diskon', CurrencyFormatter.formatIDR(order.discount));
  row('TOTAL', CurrencyFormatter.formatIDR(order.total), bold: true);
  divider();
  row('Tunai', CurrencyFormatter.formatIDR(order.paidAmount));
  row('Kembalian', CurrencyFormatter.formatIDR(order.change));
  divider();
  center('Terima kasih, datang kembali!');
  center(settings.footer);

  return lines;
}

String fitToWidth(String text, int cols) {
  if (text.length <= cols) return text;
  return '${text.substring(0, cols - 3)}...';
}

String pairColumns(String left, String right, int cols) {
  final leftFitted = fitToWidth(left, cols);
  final rightFitted = fitToWidth(right, cols);
  final gap = cols - leftFitted.length - rightFitted.length;
  if (gap >= 1) return '$leftFitted${' ' * gap}$rightFitted';
  return leftFitted;
}
