import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'dart:ui' as ui;

/// Lebar cetak printer thermal 203 dpi dalam satuan titik (dot).
const escPosDots58mm = 384;
const escPosDots80mm = 576;

/// Bitmap 1-bit siap cetak: [bits] berisi 1 untuk titik hitam, 0 untuk putih.
class MonochromeBitmap {
  const MonochromeBitmap({
    required this.width,
    required this.height,
    required this.bits,
  });

  final int width;
  final int height;
  final Uint8List bits;

  bool get isEmpty => width <= 0 || height <= 0 || bits.isEmpty;

  /// Jumlah titik hitam, berguna untuk memastikan logo tidak tercetak kosong.
  int get inkCount {
    var total = 0;
    for (final bit in bits) {
      if (bit != 0) total++;
    }
    return total;
  }
}

/// Mengubah aset gambar RGB(A) menjadi bitmap monokrom 1-bit.
///
/// Lebar hasil selalu dibulatkan ke kelipatan 8 titik karena satu baris raster
/// ESC/POS selalu utuh per byte. Mengembalikan `null` bila aset gagal dimuat
/// atau tidak menghasilkan gambar (misalnya saat dijalankan di environment
/// tanpa Flutter engine), sehingga pencetakan struk tetap berjalan tanpa logo.
Future<MonochromeBitmap?> loadMonochromeBitmap(
  String asset, {
  required int targetWidth,
  int maxHeight = 132,
  int threshold = 140,
}) async {
  if (targetWidth < 8 || maxHeight < 1) return null;
  return thresholdImageAsset(
    asset,
    targetWidth: targetWidth,
    maxHeight: maxHeight,
    threshold: threshold,
  );
}

/// Footer brand struk: logo Aksy di sebelah kiri tulisan "Aplikasi Kasir Easy".
///
/// Printer thermal tidak bisa mencetak gambar dan teks berdampingan, jadi
/// keduanya dirender jadi satu gambar 1-bit. Logo sengaja dibuat kecil agar
/// tidak memakan panjang struk.
Future<MonochromeBitmap?> buildBrandFooterBitmap({
  required String asset,
  required String text,
  required int maxWidth,
  int logoDots = 40,
  int textDots = 16,
  int gapDots = 6,
  int threshold = 150,
}) async {
  if (maxWidth < 8 || logoDots < 8) return null;
  final source = await _loadRgba(asset);
  if (source == null) return null;

  // Render 3x lalu diperkecil supaya tepi logo dan huruf tetap halus.
  const scale = 3;
  final logoSize = logoDots * scale;
  final fontSize = textDots * scale;

  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize.toDouble(),
        fontWeight: FontWeight.w800,
        color: const Color(0xFF000000),
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  if (textPainter.width <= 0) return null;

  final textWidth = textPainter.width.ceil();
  final textHeight = textPainter.height.ceil();
  final canvasWidth = logoSize + gapDots * scale + textWidth;
  final canvasHeight = [logoSize, textHeight].reduce((a, b) => a > b ? a : b);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
  );
  canvas.drawImageRect(
    source.image,
    Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    Rect.fromLTWH(0, (canvasHeight - logoSize) / 2, logoSize.toDouble(), logoSize.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  textPainter.paint(
    canvas,
    Offset(
      (logoSize + gapDots * scale).toDouble(),
      (canvasHeight - textHeight) / 2,
    ),
  );
  textPainter.dispose();

  final picture = recorder.endRecording();
  ui.Image rendered;
  try {
    rendered = await picture.toImage(canvasWidth, canvasHeight);
  } finally {
    picture.dispose();
  }
  ByteData? byteData;
  try {
    byteData = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
  } finally {
    rendered.dispose();
    source.image.dispose();
  }
  if (byteData == null) return null;

  final rgba = Uint8List.fromList(
    byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    ),
  );
  final bitmap = _thresholdRgbaRgba(
    rgba,
    srcWidth: canvasWidth,
    srcHeight: canvasHeight,
    dstWidth: _roundDownToByte((canvasWidth / scale).round()),
    dstHeight: (canvasHeight / scale).round().clamp(1, logoDots + 2),
    threshold: threshold,
  );
  if (bitmap.width > maxWidth) {
    return _scaleDown(bitmap, maxWidth);
  }
  return bitmap.isEmpty ? null : bitmap;
}

class _RgbaImage {
  const _RgbaImage({
    required this.image,
    required this.width,
    required this.height,
  });

  final ui.Image image;
  final int width;
  final int height;
}

Future<_RgbaImage?> _loadRgba(String asset) async {
  try {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final frame = await codec.getNextFrame();
    return _RgbaImage(
      image: frame.image,
      width: frame.image.width,
      height: frame.image.height,
    );
  } catch (_) {
    return null;
  }
}

Future<MonochromeBitmap?> _thresholdRgbaFuture(
  _RgbaImage source, {
  required int dstWidth,
  required int dstHeight,
  required int threshold,
}) async {
  final byteData = await source.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) return null;
  final bitmap = _thresholdRgbaRgba(
    byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    ),
    srcWidth: source.width,
    srcHeight: source.height,
    dstWidth: dstWidth,
    dstHeight: dstHeight,
    threshold: threshold,
  );
  source.image.dispose();
  return bitmap.isEmpty ? null : bitmap;
}

/// Ambang hitam/putih dengan sampling nearest-neighbour, lalu komposit di atas
/// kertas putih supaya bagian transparan tidak ikut tercetak.
MonochromeBitmap _thresholdRgbaRgba(
  Uint8List pixels, {
  required int srcWidth,
  required int srcHeight,
  required int dstWidth,
  required int dstHeight,
  required int threshold,
}) {
  final bits = Uint8List(dstWidth * dstHeight);
  const white = 255.0;
  for (var y = 0; y < dstHeight; y++) {
    final sy = (y * srcHeight / dstHeight).floor().clamp(0, srcHeight - 1);
    final rowStart = y * dstWidth;
    final sourceRow = sy * srcWidth;
    for (var x = 0; x < dstWidth; x++) {
      final sx = (x * srcWidth / dstWidth).floor().clamp(0, srcWidth - 1);
      final index = (sourceRow + sx) * 4;
      if (index + 3 >= pixels.length) continue;
      final alpha = pixels[index + 3] / 255.0;
      final luminance =
          0.299 * pixels[index] +
          0.587 * pixels[index + 1] +
          0.114 * pixels[index + 2];
      final effective = white - (white - luminance) * alpha;
      if (effective < threshold) {
        bits[rowStart + x] = 1;
      }
    }
  }
  return MonochromeBitmap(width: dstWidth, height: dstHeight, bits: bits);
}

MonochromeBitmap _scaleDown(MonochromeBitmap source, int maxWidth) {
  final width = _roundDownToByte(maxWidth);
  if (width <= 0 || width >= source.width) return source;
  final height = (source.height * width / source.width).round().clamp(1, source.height);
  final bits = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    final sy = (y * source.height / height).floor().clamp(0, source.height - 1);
    final rowStart = y * width;
    final sourceRow = sy * source.width;
    for (var x = 0; x < width; x++) {
      final sx = (x * source.width / width).floor().clamp(0, source.width - 1);
      if (source.bits[sourceRow + sx] != 0) {
        bits[rowStart + x] = 1;
      }
    }
  }
  return MonochromeBitmap(width: width, height: height, bits: bits);
}

int _roundDownToByte(int value) => (value ~/ 8) * 8;

/// Bytes per baris raster untuk lebar tertentu.
int escPosBytesPerLine(int width) => (width + 7) ~/ 8;

/// Mengubah [bitmap] menjadi perintah gambar raster ESC/POS (`GS v 0`).
///
/// Perintah dipisah menjadi beberapa band karena panjang data maksimum satu
/// perintah adalah 65535 byte.
Uint8List buildRasterImageEscPos(MonochromeBitmap bitmap) {
  if (bitmap.isEmpty) return Uint8List(0);
  final bytesPerLine = escPosBytesPerLine(bitmap.width);
  final maxRows = (255 * 256 ~/ bytesPerLine).clamp(1, bitmap.height);
  final buffer = BytesBuilder();

  for (var start = 0; start < bitmap.height; start += maxRows) {
    final rows = (bitmap.height - start) < maxRows
        ? bitmap.height - start
        : maxRows;
    buffer.add(<int>[
      0x1D,
      0x76,
      0x30,
      0x00,
      bytesPerLine & 0xFF,
      (bytesPerLine >> 8) & 0xFF,
      rows & 0xFF,
      (rows >> 8) & 0xFF,
    ]);
    for (var row = 0; row < rows; row++) {
      final line = Uint8List(bytesPerLine);
      final source = (start + row) * bitmap.width;
      for (var x = 0; x < bitmap.width; x++) {
        if (bitmap.bits[source + x] != 0) {
          line[x >> 3] |= 0x80 >> (x & 7);
        }
      }
      buffer.add(line);
    }
  }

  return buffer.toBytes();
}

/// Footer brand sebagai gambar, dicetak rata tengah di bagian paling bawah
/// struk thermal.
Uint8List buildReceiptLogoEscPos(MonochromeBitmap? bitmap) {
  if (bitmap == null || bitmap.isEmpty) return Uint8List(0);
  final buffer = BytesBuilder()
    ..add(const <int>[0x1B, 0x61, 0x01])
    ..add(buildRasterImageEscPos(bitmap))
    ..add(const <int>[0x1B, 0x61, 0x00]);
  return buffer.toBytes();
}

/// Dipakai ulang oleh [loadMonochromeBitmap] agar ambang dan sampling identik
/// dengan footer brand.
Future<MonochromeBitmap?> thresholdImageAsset(
  String asset, {
  required int targetWidth,
  required int maxHeight,
  required int threshold,
}) async {
  final source = await _loadRgba(asset);
  if (source == null) return null;
  final bitmap = await _thresholdRgbaFuture(
    source,
    dstWidth: targetWidth,
    dstHeight: maxHeight,
    threshold: threshold,
  );
  return bitmap;
}
