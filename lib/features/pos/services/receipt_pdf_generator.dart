import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/data/app_store.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/order.dart';

Future<Uint8List> generateReceiptPdf({
  required Order order,
  required AppStore store,
  required bool wide,
}) async {
  final width = wide ? 80 * PdfPageFormat.mm : 57 * PdfPageFormat.mm;
  final margin = 2 * PdfPageFormat.mm;
  final fontSize = wide ? 10.5 : 9.0;
  final lineHeight = fontSize * 1.4;
  final cols = wide ? 32 : 23;

  final content = _receiptLines(order, store, cols);
  final height = margin * 2 + (content.length + 1) * lineHeight;

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(width, height, marginAll: margin),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          for (final line in content)
            pw.Text(
              line.text,
              textAlign: line.align,
              style: pw.TextStyle(
                font: line.bold ? pw.Font.courierBold() : pw.Font.courier(),
                fontSize: fontSize,
                height: lineHeight / fontSize,
              ),
            ),
        ],
      ),
    ),
  );
  return doc.save();
}

class _Line {
  const _Line(this.text, {this.align = pw.TextAlign.left, this.bold = false});

  final String text;
  final pw.TextAlign align;
  final bool bold;
}

List<_Line> _receiptLines(
  Order order,
  AppStore store,
  int cols,
) {
  final settings = store.settings;
  final shift = store.activeShift;
  final lines = <_Line>[];

  void center(String text, {bool bold = false}) {
    if (text.trim().isEmpty) return;
    lines.add(_Line(_fit(text, cols), align: pw.TextAlign.center, bold: bold));
  }

  void row(String left, String right, {bool bold = false}) {
    lines.add(_Line(_pair(left, right, cols), bold: bold));
  }

  void left(String text, {bool bold = false}) {
    lines.add(_Line(_fit(text, cols), bold: bold));
  }

  void divider() {
    lines.add(_Line('-' * cols, align: pw.TextAlign.center));
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

String _fit(String text, int cols) {
  if (text.length <= cols) return text;
  return '${text.substring(0, cols - 3)}...';
}

String _pair(String left, String right, int cols) {
  final leftFitted = _fit(left, cols);
  final rightFitted = _fit(right, cols);
  final gap = cols - leftFitted.length - rightFitted.length;
  if (gap >= 1) return '$leftFitted${' ' * gap}$rightFitted';
  return leftFitted;
}