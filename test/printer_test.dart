import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aksy/core/data/app_store.dart';
import 'package:aksy/features/pos/models/cart_item.dart';
import 'package:aksy/features/pos/models/order.dart';
import 'package:aksy/features/pos/models/product.dart';
import 'package:aksy/features/pos/services/receipt_layout.dart';
import 'package:aksy/features/printer/models/printer_settings.dart';
import 'package:aksy/features/printer/services/esc_pos_receipt.dart';

void main() {
  final drink = Product(
    id: 'p1',
    name: 'Es Teh',
    price: 5000,
    category: 'Minuman',
    icon: Icons.local_drink,
    stock: 100,
    costPrice: 2000,
  );

  Order buildOrder() => Order(
    id: 'TRX1',
    createdAt: DateTime(2026, 3, 10, 14, 5),
    items: [CartItem(product: drink, quantity: 2)],
    paidAmount: 20000,
    discount: 1000,
  );

  group('receipt layout', () {
    test('column counts match 58mm and 80mm paper', () {
      expect(receiptColumns(wide: false), 32);
      expect(receiptColumns(wide: true), 48);
    });

    test('no line exceeds the column limit', () {
      final longName = Product(
        id: 'p2',
        name: 'Nudgeveryveryverylongproductnamehere',
        price: 5000,
        category: 'Minuman',
        icon: Icons.local_drink,
        stock: 10,
      );
      final order = Order(
        id: 'TRX2',
        createdAt: DateTime(2026, 3, 10),
        items: [CartItem(product: longName, quantity: 1)],
        paidAmount: 5000,
      );
      for (final wide in [false, true]) {
        final cols = receiptColumns(wide: wide);
        final lines = buildReceiptLines(
          order: order,
          store: AppStore(products: [longName]),
          cols: cols,
        );
        for (final line in lines) {
          expect(line.text.length, lessThanOrEqualTo(cols));
        }
      }
    });

    test('pairColumns keeps both values and pads the gap', () {
      final result = pairColumns('TOTAL', 'Rp 9.000', 32);
      expect(result, 'TOTAL${' ' * 19}Rp 9.000');
      expect(result.length, 32);
    });

    test('pairColumns drops the right value when there is no room', () {
      final result = pairColumns(
        'left value that is very long indeed',
        'Rp 9.000',
        10,
      );
      expect(result.length, lessThanOrEqualTo(10));
      expect(result, 'left va...');
    });

    test('fitToWidth truncates with an ellipsis', () {
      expect(fitToWidth('abcdefghij', 5), 'ab...');
      expect(fitToWidth('abc', 5), 'abc');
    });
  });

  group('EscPosBuilder', () {
    test('initialize emits ESC @ and sets the character table', () {
      final bytes = (EscPosBuilder(columns: 32)..initialize()).build();
      expect(bytes.sublist(0, 2), [0x1B, 0x40]);
      expect(bytes.sublist(2, 5), [0x1B, 0x74, 0x10]);
    });

    test('align and bold emit the expected commands', () {
      final bytes = (EscPosBuilder(columns: 32)
            ..align(ReceiptAlign.center)
            ..bold(on: true)
            ..line('X'))
          .build();
      expect(bytes.sublist(0, 3), [0x1B, 0x61, 0x01]);
      expect(bytes.sublist(3, 6), [0x1B, 0x45, 0x01]);
      expect(bytes[6], 'X'.codeUnitAt(0));
      expect(bytes[7], 0x0A);
      expect(bytes.length, 8);
    });

    test('encodeText maps runes above latin-1 to a question mark', () {
      expect(EscPosBuilder.encodeText('a\u00e9\u4e2d'), [0x61, 0xE9, 0x3F]);
    });

    test('every generated line ends with a line feed', () {
      final builder = EscPosBuilder(columns: 32)
        ..line('one')
        ..line('two');
      final bytes = builder.build();
      expect(bytes[bytes.length - 1], 0x0A);
      expect(bytes.where((b) => b == 0x0A).length, 2);
    });
  });

  group('buildReceiptEscPos', () {
    test('produces a non-empty payload for both paper widths', () {
      final store = AppStore(products: [drink]);
      for (final wide in [true, false]) {
        final bytes = buildReceiptEscPos(
          order: buildOrder(),
          store: store,
          wide: wide,
        );
        expect(bytes, isNotEmpty);
        expect(bytes.first, 0x1B);
      }
    });

    test('payload starts with init and ends with the cut command', () {
      final store = AppStore(products: [drink]);
      final bytes = buildReceiptEscPos(
        order: buildOrder(),
        store: store,
        wide: false,
      );
      expect(bytes.sublist(0, 2), [0x1B, 0x40]);
      expect(bytes.sublist(bytes.length - 3), [0x1D, 0x56, 0x00]);
    });

    test('payload contains the order number and total as plain text', () {
      final store = AppStore(products: [drink]);
      final bytes = buildReceiptEscPos(
        order: buildOrder(),
        store: store,
        wide: false,
      );
      final text = String.fromCharCodes(bytes);
      expect(text, contains('TRX1'));
      expect(text, contains('TOTAL'));
      expect(text, contains('Rp 9.000'));
    });

    test('works for an order with no items and no change', () {
      final store = AppStore(products: const []);
      final bytes = buildReceiptEscPos(
        order: Order(
          id: 'TRX0',
          createdAt: DateTime(2026, 3, 10),
          items: const [],
          paidAmount: 0,
        ),
        store: store,
        wide: true,
      );
      expect(bytes, isNotEmpty);
    });
  });

  group('buildTestEscPos', () {
    test('produces a valid payload for both widths', () {
      for (final wide in [true, false]) {
        final bytes = buildTestEscPos(wide: wide);
        expect(bytes, isNotEmpty);
        expect(bytes.first, 0x1B);
        expect(bytes.sublist(bytes.length - 3), [0x1D, 0x56, 0x00]);
      }
    });
  });

  group('PrinterSettings', () {
    test('is not configured until an address is set', () {
      expect(const PrinterSettings().isConfigured, isFalse);
      expect(
        const PrinterSettings(deviceAddress: '00:11:22:33:44:55').isConfigured,
        isTrue,
      );
    });

    test('round-trips through json', () {
      const settings = PrinterSettings(
        deviceAddress: '00:11:22:33:44:55',
        deviceName: 'Rongta RP58',
        wide: true,
        autoPrint: true,
        copies: 3,
      );
      final restored = PrinterSettings.fromJson(settings.toJson());
      expect(restored.deviceAddress, settings.deviceAddress);
      expect(restored.deviceName, settings.deviceName);
      expect(restored.wide, isTrue);
      expect(restored.autoPrint, isTrue);
      expect(restored.copies, 3);
    });

    test('falls back to safe defaults for missing json fields', () {
      final restored = PrinterSettings.fromJson(const {});
      expect(restored.deviceAddress, '');
      expect(restored.wide, isFalse);
      expect(restored.autoPrint, isFalse);
      expect(restored.copies, 1);
    });
  });
}
