import 'dart:typed_data';

import '../../../core/data/app_store.dart';
import '../../../core/utils/date_formatter.dart';
import '../../pos/models/order.dart';
import '../../pos/services/receipt_layout.dart';

class EscPosBuilder {
  EscPosBuilder({required this.columns});

  final int columns;
  final BytesBuilder _buffer = BytesBuilder();

  static const _init = [0x1B, 0x40];
  static const _alignLeft = [0x1B, 0x61, 0x00];
  static const _alignCenter = [0x1B, 0x61, 0x01];
  static const _boldOn = [0x1B, 0x45, 0x01];
  static const _boldOff = [0x1B, 0x45, 0x00];
  static const _feedLines = [0x1B, 0x64];
  static const _cut = [0x1D, 0x56, 0x00];

  void _raw(List<int> bytes) => _buffer.add(bytes);

  void initialize() {
    _raw(_init);
    _raw(const [0x1B, 0x74, 0x10]);
  }

  void align(ReceiptAlign align) {
    _raw(align == ReceiptAlign.center ? _alignCenter : _alignLeft);
  }

  void bold({required bool on}) {
    _raw(on ? _boldOn : _boldOff);
  }

  void line(String text) {
    _raw(encodeText(text));
    _raw(const [0x0A]);
  }

  void feed(int lines) {
    _raw([..._feedLines, lines.clamp(0, 255)]);
  }

  void cut() {
    feed(1);
    _raw(_cut);
  }

  Uint8List build() => _buffer.toBytes();

  static List<int> encodeText(String text) {
    final bytes = <int>[];
    for (final rune in text.runes) {
      if (rune <= 0xFF) {
        bytes.add(rune);
      } else {
        bytes.add(0x3F);
      }
    }
    return bytes;
  }
}

Uint8List buildReceiptEscPos({
  required Order order,
  required AppStore store,
  required bool wide,
  bool cut = true,
}) {
  final cols = receiptColumns(wide: wide);
  final lines = buildReceiptLines(order: order, store: store, cols: cols);
  final builder = EscPosBuilder(columns: cols)..initialize();

  for (final line in lines) {
    builder
      ..align(line.align)
      ..bold(on: line.bold)
      ..line(line.text);
  }

  builder
    ..align(ReceiptAlign.left)
    ..bold(on: false)
    ..feed(3);
  if (cut) {
    builder.cut();
  }

  return builder.build();
}

Uint8List buildTestEscPos({bool wide = false, bool cut = true}) {
  final cols = receiptColumns(wide: wide);
  final builder = EscPosBuilder(columns: cols)..initialize()
    ..align(ReceiptAlign.center)
    ..bold(on: true)
    ..line('TES CETAK')
    ..bold(on: false)
    ..line('Aplikasi Kasir Easy')
    ..feed(1)
    ..line(DateFormatter.when(DateTime.now()))
    ..feed(1)
    ..line('-' * cols)
    ..line('Printer termal siap digunakan')
    ..line('Lebar: ${wide ? '80' : '58'}mm - $cols karakter')
    ..feed(3);
  if (cut) {
    builder.cut();
  }

  return builder.build();
}
