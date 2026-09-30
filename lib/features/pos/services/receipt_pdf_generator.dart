import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/data/app_store.dart';
import '../../../core/utils/print_text_sanitizer.dart';
import '../models/order.dart';
import 'receipt_layout.dart';

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

  final content = buildReceiptLines(order: order, store: store, cols: cols);
  final visualLines = content.fold<int>(
    0,
    (total, line) => total + '\n'.allMatches(line.text).length + 1,
  );
  final height = margin * 2 + (visualLines + 1) * lineHeight;

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(width, height, marginAll: margin),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          for (final line in content)
            pw.Text(
              sanitizePdfText(line.text),
              textAlign: line.align == ReceiptAlign.center
                  ? pw.TextAlign.center
                  : pw.TextAlign.left,
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
