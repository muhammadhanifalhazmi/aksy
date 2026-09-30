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

  int get lineCount => '\n'.allMatches(text).length + 1;
}

int receiptColumns({required bool wide}) => wide ? 48 : 32;

List<ReceiptLine> buildReceiptLines({
  required Order order,
  required AppStore store,
  required int cols,
  bool includeBrandText = true,
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

  void blank() {
    lines.add(const ReceiptLine('', align: ReceiptAlign.center));
  }

  center(settings.name, bold: true);
  center(settings.address);
  center(settings.phone);
  blank();
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
  if (order.discount > 0) {
    row('Diskon', '-${CurrencyFormatter.formatIDR(order.discount)}');
  }
  row('TOTAL', CurrencyFormatter.formatIDR(order.total), bold: true);
  divider();
  row('Tunai', CurrencyFormatter.formatIDR(order.paidAmount));
  row('Kembalian', CurrencyFormatter.formatIDR(order.change));
  divider();
  for (final text in receiptFooterLines(settings.footer)) {
    center(text);
  }
  if (includeBrandText) {
    lines.addAll(receiptBrandLines(cols));
  }

  return lines;
}

/// Penanda Aplikasi Kasir Easy di bagian paling bawah struk.
///
/// Struk PDF dan pratinjau layar memakai baris teks biasa, sedangkan struk
/// thermal mencetak logo dan nama aplikasi sebagai satu gambar raster 1-bit
/// supaya bisa tampil berdampingan (lihat `buildBrandFooterBitmap`).
const receiptBrandName = 'Aplikasi Kasir Easy';
const receiptBrandAsset = 'assets/images/brand_logo.png';

List<ReceiptLine> receiptBrandLines(int cols) {
  return [
    const ReceiptLine('', align: ReceiptAlign.center),
    ReceiptLine(
      fitToWidth(receiptBrandName, cols),
      align: ReceiptAlign.center,
      bold: true,
    ),
  ];
}

List<String> receiptFooterLines(String footer) {
  const thanks = 'Terima kasih, datang kembali!';
  final custom = footer.trim();
  if (custom.isEmpty) return const [thanks];
  if (custom.toLowerCase().contains('terima kasih')) return [custom];
  return [thanks, custom];
}

String fitToWidth(String text, int cols) {
  if (text.length <= cols) return text;
  return '${text.substring(0, cols - 3)}...';
}

String pairColumns(String left, String right, int cols) {
  final rightFitted = fitToWidth(right, cols);
  final leftFull = fitToWidth(left, cols);
  final leftBudget = cols - rightFitted.length - 1;
  if (leftBudget >= 3) {
    final leftFitted = fitToWidth(left, leftBudget);
    final gap = cols - leftFitted.length - rightFitted.length;
    if (gap >= 1) return '$leftFitted${' ' * gap}$rightFitted';
  }
  final padding = cols - rightFitted.length;
  return '$leftFull\n${' ' * (padding < 0 ? 0 : padding)}$rightFitted';
}
