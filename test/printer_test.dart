import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aksy/core/data/app_store.dart';
import 'package:aksy/core/data/store_settings.dart';
import 'package:aksy/features/pos/models/cart_item.dart';
import 'package:aksy/features/pos/models/order.dart';
import 'package:aksy/features/pos/models/product.dart';
import 'package:aksy/features/pos/services/receipt_layout.dart';
import 'package:aksy/features/printer/models/printer_settings.dart';
import 'package:aksy/features/printer/services/esc_pos_image.dart';
import 'package:aksy/features/printer/services/esc_pos_receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
          for (final part in line.text.split('\n')) {
            expect(part.length, lessThanOrEqualTo(cols));
          }
        }
      }
    });

    test('pairColumns keeps both values and pads the gap', () {
      final result = pairColumns('TOTAL', 'Rp 9.000', 32);
      expect(result, 'TOTAL${' ' * 19}Rp 9.000');
      expect(result.length, 32);
    });

    test('pairColumns keeps the right value on its own line when tight', () {
      final result = pairColumns(
        'left value that is very long indeed',
        'Rp 9.000',
        10,
      );
      final parts = result.split('\n');
      expect(parts, hasLength(2));
      expect(parts.first.length, lessThanOrEqualTo(10));
      expect(parts.last.trim(), 'Rp 9.000');
    });

    test('pairColumns never drops the amount on a 58mm receipt', () {
      final order = Order(
        id: 'TRX2',
        createdAt: DateTime(2026, 3, 10),
        items: [
          CartItem(
            product: Product(
              id: 'p3',
              name: 'Paket Hemat',
              price: 1500000,
              category: 'Paket',
              icon: Icons.local_drink,
              stock: 10,
              wholesalePrice: 1500000,
              minWholesaleQty: 2,
            ),
            quantity: 2,
          ),
        ],
        paidAmount: 3000000,
      );
      final lines = buildReceiptLines(
        order: order,
        store: AppStore(products: [order.items.first.product]),
        cols: receiptColumns(wide: false),
      );
      final text = lines.map((l) => l.text).join('\n');
      expect(text, contains('Rp 3.000.000'));
    });

    test('every receipt carries the Aplikasi Kasir Easy branding once', () {
      final store = AppStore(products: [drink])
        ..updateStoreSettings(const StoreSettings(name: 'Toko Berkah'));
      for (final wide in [true, false]) {
        final cols = receiptColumns(wide: wide);
        final lines = buildReceiptLines(
          order: buildOrder(),
          store: store,
          cols: cols,
        );
        final text = lines.map((l) => l.text).join('\n');
        expect(
          '\n$text\n'.split(receiptBrandName).length - 1,
          1,
          reason: 'nama aplikasi harus muncul tepat satu kali',
        );
        expect(text, isNot(contains('Kasir untuk UMKM')));

        final brand = lines.lastWhere((l) => l.text.contains(receiptBrandName));
        expect(brand.align, ReceiptAlign.center);
        expect(brand.bold, isTrue);
        expect(brand.text.length, lessThanOrEqualTo(cols));
      }
    });

    test('receiptBrandLines has a blank spacer line and fits narrow paper', () {
      final lines = receiptBrandLines(receiptColumns(wide: false));
      expect(lines.first.text, isEmpty);
      expect(lines, hasLength(2));
      for (final line in lines) {
        expect(line.lineCount, 1);
        expect(line.text.length, lessThanOrEqualTo(32));
      }
    });

    test('includeBrandText false drops the app name from the text lines', () {
      final store = AppStore(products: [drink])
        ..updateStoreSettings(const StoreSettings(name: 'Toko Berkah'));
      final withText = buildReceiptLines(
        order: buildOrder(),
        store: store,
        cols: 32,
      );
      final withoutText = buildReceiptLines(
        order: buildOrder(),
        store: store,
        cols: 32,
        includeBrandText: false,
      );
      expect(
        withText.map((l) => l.text).join('\n'),
        contains(receiptBrandName),
      );
      expect(
        withoutText.map((l) => l.text).join('\n'),
        isNot(contains(receiptBrandName)),
        reason: 'struk thermal mencetak nama aplikasi sebagai gambar raster',
      );
      expect(withoutText.length, withText.length - 2);
    });

    test('discount row is hidden when there is no discount', () {
      final order = Order(
        id: 'TRX3',
        createdAt: DateTime(2026, 3, 10),
        items: [CartItem(product: drink, quantity: 1)],
        paidAmount: 5000,
      );
      final lines = buildReceiptLines(
        order: order,
        store: AppStore(products: [drink]),
        cols: 32,
      );
      expect(lines.any((l) => l.text.startsWith('Diskon')), isFalse);

      final withDiscount = buildReceiptLines(
        order: buildOrder(),
        store: AppStore(products: [drink]),
        cols: 32,
      );
      expect(
        withDiscount.any((l) => l.text.contains('Diskon')),
        isTrue,
      );
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

    test('encodeText transliterates accents and drops non-ascii runes', () {
      expect(EscPosBuilder.encodeText('a\u00e9\u4e2d'), [0x61, 0x65, 0x3F]);
      expect(EscPosBuilder.encodeText('Kedai \u2014 Kopi\u2019s'), [
        0x4B,
        0x65,
        0x64,
        0x61,
        0x69,
        0x20,
        0x2D,
        0x20,
        0x4B,
        0x6F,
        0x70,
        0x69,
        0x27,
        0x73,
      ]);
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

    test('prints the brand footer as a raster image at the very bottom', () {
      final store = AppStore(products: [drink])
        ..updateStoreSettings(const StoreSettings(name: 'Toko Berkah'));
      // 16 x 2 titik: baris pertama seluruhnya hitam, baris kedua putih.
      final brand = MonochromeBitmap(
        width: 16,
        height: 2,
        bits: Uint8List.fromList([
          ...List<int>.filled(16, 1),
          ...List<int>.filled(16, 0),
        ]),
      );

      final bytes = buildReceiptEscPos(
        order: buildOrder(),
        store: store,
        wide: false,
        brand: brand,
      );

      // Teks dulu, baru gambar brand di paling bawah.
      expect(String.fromCharCodes(bytes), contains('TRX1'));
      expect(String.fromCharCodes(bytes), contains('Toko Berkah'));
      final text = String.fromCharCodes(bytes);
      expect(text, isNot(contains(receiptBrandName)),
          reason: 'nama aplikasi dicetak sebagai gambar, bukan teks');
      expect(_countRasterCommands(bytes), 1);
      final rasterAt = _indexOfRasterCommand(bytes);
      final cutAt = _indexOf(bytes, const [0x1D, 0x56]);
      final feedAt = _indexOf(bytes, const [0x1B, 0x64, 0x03]);
      expect(rasterAt, greaterThan(text.lastIndexOf('Toko Berkah')));
      expect(rasterAt, lessThan(feedAt));
      expect(feedAt, lessThan(cutAt));
      // ESC a 1 (rata tengah) sebelum gambar, ESC a 0 (rata kiri) sesudahnya.
      expect(bytes.sublist(rasterAt - 3, rasterAt), [0x1B, 0x61, 0x01]);
      expect(bytes.sublist(rasterAt + 8 + 4, rasterAt + 8 + 7), [0x1B, 0x61, 0x00]);
    });

    test('omits the brand block when no bitmap is supplied', () {
      final store = AppStore(products: [drink])
        ..updateStoreSettings(const StoreSettings(name: 'Toko Berkah'));
      final order = buildOrder();
      final withoutBrand = buildReceiptEscPos(
        order: order,
        store: store,
        wide: false,
      );
      final brand = MonochromeBitmap(width: 16, height: 2, bits: Uint8List(32));
      final withBrand = buildReceiptEscPos(
        order: order,
        store: store,
        wide: false,
        brand: brand,
      );

      expect(buildReceiptLogoEscPos(null), isEmpty);
      expect(
        withBrand.length,
        withoutBrand.length + buildReceiptLogoEscPos(brand).length,
      );
      expect(_countRasterCommands(withoutBrand), 0);
      expect(_countRasterCommands(withBrand), 1);
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

    test('works for an order with no items and no change', () {      final store = AppStore(products: const []);
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

  group('esc/pos logo raster', () {    test('packs one bit per dot, MSB first, and pads rows to whole bytes', () {
      final bitmap = MonochromeBitmap(
        width: 16,
        height: 3,
        bits: Uint8List.fromList(List<int>.filled(48, 0)..[0] = 1),
      );
      final raster = buildRasterImageEscPos(bitmap);

      expect(escPosBytesPerLine(16), 2);
      expect(raster.sublist(0, 8), [
        0x1D, 0x76, 0x30, 0x00, //
        0x02, 0x00, 0x03, 0x00,
      ]);
      expect(raster.length, 8 + 2 * 3);
      expect(raster[8], 0x80, reason: 'titik pertama harus bit paling kiri');
      expect(raster[9], 0x00);
      expect(raster.sublist(10, 14), [0, 0, 0, 0]);
    });

    test('splits tall images into bands so one command stays under 64KB', () {
      // 384 titik = 48 byte per baris, sehingga satu band maksimum 1365 baris.
      final width = 384;
      final height = 3000;
      final bytesPerLine = width ~/ 8;
      const maxRowsPerBand = 255 * 256 ~/ 48;
      final bitmap = MonochromeBitmap(
        width: width,
        height: height,
        bits: Uint8List(height * width),
      );
      final raster = buildRasterImageEscPos(bitmap);

      // 1365 + 1365 + 270 baris, masing-masing diawali header 8 byte.
      final expected = 3 * 8 +
          bytesPerLine * (maxRowsPerBand + maxRowsPerBand + (height - 2 * maxRowsPerBand));
      expect(raster.length, expected);
      expect(raster.length % 8, 0, reason: 'setiap band diawali header 8 byte');
      // Perintah pertama tidak boleh melebihi batas 65535 byte.
      expect(8 + bytesPerLine * maxRowsPerBand, lessThanOrEqualTo(65535));
    });

    test('empty or missing bitmaps produce no bytes', () {
      expect(
        buildRasterImageEscPos(
          MonochromeBitmap(width: 0, height: 0, bits: Uint8List(0)),
        ),
        isEmpty,
      );
      expect(buildReceiptLogoEscPos(null), isEmpty);
    });

    test('real logo asset converts to a printable bitmap', () async {
      final bitmap = await loadMonochromeBitmap(
        receiptBrandAsset,
        targetWidth: 208,
        maxHeight: 208,
      );
      expect(bitmap, isNotNull);
      final logo = bitmap!;
      expect(logo.width, 208);
      expect(logo.width % 8, 0, reason: 'lebar harus kelipatan 8 titik');
      expect(logo.height, lessThanOrEqualTo(208));
      expect(logo.inkCount, greaterThan(0), reason: 'logo tidak boleh kosong');
      // 21% tinta pada aset asli; toleransi longgar agar aman terhadap
      // perbedaan rendering antar platform.
      final inkRatio = logo.inkCount / (logo.width * logo.height);
      expect(inkRatio, greaterThan(0.08));
      expect(inkRatio, lessThan(0.45));

      final raster = buildRasterImageEscPos(logo);
      expect(raster.length, 8 + (logo.width ~/ 8) * logo.height);
    });

    test('rejects impossible sizes instead of throwing', () async {
      expect(
        await loadMonochromeBitmap(receiptBrandAsset, targetWidth: 4),
        isNull,
      );
      expect(
        await loadMonochromeBitmap(
          'assets/images/tidak_ada.png',
          targetWidth: 208,
        ),
        isNull,
      );
    });

    test('brand footer keeps the logo on the left of the app name', () async {
      final brand = await buildBrandFooterBitmap(
        asset: receiptBrandAsset,
        text: receiptBrandName,
        maxWidth: 280,
        logoDots: 48,
        textDots: 15,
        gapDots: 6,
      );
      expect(brand, isNotNull);
      final footer = brand!;
      expect(footer.width % 8, 0, reason: 'lebar harus kelipatan 8 titik');
      expect(footer.width, lessThanOrEqualTo(280));
      // 48 titik = 6 mm, jauh lebih kecil daripada lebar kertas 58 mm.
      expect(footer.height, lessThanOrEqualTo(50));
      expect(footer.inkCount, greaterThan(0));

      // Kolom kiri harus berisi logo (pola rapat), kolom kanan teks (pola
      // bergaris) sehingga logo tidak berada di tengah atau di kanan.
      final third = footer.width ~/ 3;
      final leftInk = _inkRatio(footer, 0, third);
      final rightInk = _inkRatio(footer, third, footer.width - third);
      expect(leftInk, greaterThan(0.02), reason: 'logo harus ada di kiri');
      expect(rightInk, greaterThan(0.02), reason: 'nama aplikasi ada di kanan');

      final raster = buildRasterImageEscPos(footer);
      expect(raster.length, 8 + (footer.width ~/ 8) * footer.height);
    });

    test('brand footer shrinks to fit narrow paper', () async {
      final brand = await buildBrandFooterBitmap(
        asset: receiptBrandAsset,
        text: receiptBrandName,
        maxWidth: 160,
        logoDots: 48,
        textDots: 15,
      );
      expect(brand, isNotNull);
      expect(brand!.width, lessThanOrEqualTo(160));
      expect(brand.inkCount, greaterThan(0));
    });

    test('missing asset yields no brand footer', () async {
      expect(
        await buildBrandFooterBitmap(
          asset: 'assets/images/tidak_ada.png',
          text: receiptBrandName,
          maxWidth: 280,
        ),
        isNull,
      );
    });
  });
}

double _inkRatio(MonochromeBitmap bitmap, int from, int to) {
  var ink = 0;
  var total = 0;
  for (var y = 0; y < bitmap.height; y++) {
    for (var x = from; x < to && x < bitmap.width; x++) {
      if (bitmap.bits[y * bitmap.width + x] != 0) ink++;
      total++;
    }
  }
  return total == 0 ? 0 : ink / total;
}

int _countRasterCommands(List<int> bytes) {
  var count = 0;
  for (var i = 0; i + 2 < bytes.length; i++) {
    if (bytes[i] == 0x1D && bytes[i + 1] == 0x76 && bytes[i + 2] == 0x30) {
      count++;
    }
  }
  return count;
}

int _indexOfRasterCommand(List<int> bytes) =>
    _indexOf(bytes, const [0x1D, 0x76, 0x30]);

int _indexOf(List<int> bytes, List<int> pattern) {
  for (var i = 0; i + pattern.length <= bytes.length; i++) {
    var match = true;
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1;
}
