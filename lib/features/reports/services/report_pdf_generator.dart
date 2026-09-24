import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/data/app_store.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../features/pos/models/product.dart';
import '../models/report_period.dart';

const _primary = PdfColor.fromInt(0xFF34A99D);
const _secondary = PdfColor.fromInt(0xFF458393);
const _ink = PdfColor.fromInt(0xFF1B1B1B);
const _muted = PdfColor.fromInt(0xFF6B6B6B);
const _line = PdfColor.fromInt(0xFFE0E5E0);
const _gutter = PdfColor.fromInt(0xFFF4F7F4);

double get _contentWidth => PdfPageFormat.a4.width - 72;

const _palette = <PdfColor>[
  PdfColor.fromInt(0xFF34A99D),
  PdfColor.fromInt(0xFF458393),
  PdfColor.fromInt(0xFF2E7D32),
  PdfColor.fromInt(0xFFF57C00),
  PdfColor.fromInt(0xFF1976D2),
  PdfColor.fromInt(0xFF7B1FA2),
  PdfColor.fromInt(0xFFC62828),
  PdfColor.fromInt(0xFFE91E63),
];

Future<Uint8List> generateReportPdf({
  required AppStore store,
  required ReportPeriod period,
}) async {
  final doc = pw.Document(
    title: period.title,
    theme: pw.ThemeData.withFont(base: pw.Font.helvetica()),
  );

  final weekLabel = _periodBucketType(period);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 38),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(color: _muted, fontSize: 8),
        ),
      ),
      build: (ctx) {
        final sections = <pw.Widget>[
          _buildHeader(period),
          _buildSummary(store, period),
          pw.SizedBox(height: 22),
          _buildSectionTitle('Penjualan per $weekLabel'),
          _buildTrendChart(store, period),
        ];

        final categories = store.categoryRevenueBetween(
          period.start,
          period.endExclusive,
        );
        if (categories.isNotEmpty) {
          sections.addAll([
            pw.SizedBox(height: 26),
            _buildSectionTitle('Kontribusi per Kategori'),
            _buildCategorySection(categories),
          ]);
        }

        final topProducts = store.topProductsBetween(
          period.start,
          period.endExclusive,
        );
        if (topProducts.isNotEmpty) {
          sections.addAll([
            pw.SizedBox(height: 26),
            _buildSectionTitle('Produk Terlaris'),
            _buildTopProducts(topProducts),
          ]);
        }

        sections.addAll([
          pw.SizedBox(height: 26),
          _buildSectionTitle('Rincian per ${period.type == ReportPeriodType.daily ? 'Jam' : weekLabel}'),
          _buildDetailTable(store, period),
          pw.SizedBox(height: 26),
          _buildSectionTitle('Arus Kas'),
          _buildCashFlow(store, period),
          pw.SizedBox(height: 18),
          _buildTimestamp(period),
        ]);

        return sections;
      },
    ),
  );

  return doc.save();
}

String _periodBucketType(ReportPeriod period) {
  switch (period.type) {
    case ReportPeriodType.daily:
      return 'Jam';
    case ReportPeriodType.weekly:
    case ReportPeriodType.monthly:
      return 'Hari';
    case ReportPeriodType.quarterly:
    case ReportPeriodType.yearly:
      return 'Bulan';
  }
}

pw.Widget _buildHeader(ReportPeriod period) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(
        width: 44,
        height: 44,
        decoration: pw.BoxDecoration(
          color: _primary,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        alignment: pw.Alignment.center,
        child: pw.Text(
          'AKS',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.SizedBox(width: 14),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Aplikasi Kasir Easy',
              style: pw.TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Jl. Merdeka No. 45, Jakarta',
              style: pw.TextStyle(color: _muted, fontSize: 9),
            ),
          ],
        ),
      ),
      pw.SizedBox(width: 12),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _primary,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          period.title,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}

pw.Widget _buildSummary(AppStore store, ReportPeriod period) {
  final omzet = store.omzetBetween(period.start, period.endExclusive);
  final profit = store.estimatedProfitBetween(period.start, period.endExclusive);
  final trx = store.transactionCountBetween(period.start, period.endExclusive);
  final items = store.itemsSoldBetween(period.start, period.endExclusive);
  final avg = trx > 0 ? omzet ~/ trx : 0;

  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          period.rangeLabel,
          style: pw.TextStyle(color: _ink, fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          trx > 0
              ? 'Rata-rata nilai transaksi: ${CurrencyFormatter.formatIDR(avg)}'
              : 'Belum ada transaksi pada periode ini.',
          style: pw.TextStyle(color: _muted, fontSize: 9),
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Omzet', 'Estimasi Laba', 'Transaksi', 'Item Terjual'],
          data: [
            [
              _money(omzet),
              _money(profit),
              '$trx',
              '$items',
            ],
          ],
          headerStyle: pw.TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: pw.TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: const pw.BoxDecoration(color: _gutter),
          cellAlignments: const {
            0: pw.Alignment.center,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
          },
          border: pw.TableBorder.all(color: _line, width: 0.6),
          cellPadding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        ),
      ],
    ),
  );
}

String _money(int value) => 'Rp ${_grouped(value)}';

String _grouped(int value) {
  final s = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
    buffer.write(s[i]);
  }
  return (value < 0 ? '-' : '') + buffer.toString();
}

pw.Widget _buildSectionTitle(String title) {
  return pw.Row(
    children: [
      pw.Container(
        width: 4,
        height: 16,
        decoration: pw.BoxDecoration(
          color: _primary,
          borderRadius: pw.BorderRadius.circular(2),
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Text(
        title,
        style: pw.TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );
}

pw.Widget _buildTrendChart(AppStore store, ReportPeriod period) {
  final buckets = _buildBuckets(store, period);
  if (buckets.every((b) => b.omzet == 0)) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.all(22),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: _gutter,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        'Tidak ada data penjualan pada periode ini.',
        style: pw.TextStyle(color: _muted, fontSize: 10),
      ),
    );
  }

  final n = buckets.length;
  final labels = [for (final b in buckets) b.label];
  final values = [for (final b in buckets) b.omzet];
  final maxV = values.reduce(math.max);
  final niceMax = _niceCeil(maxV);
  final half = (niceMax / 2).round();
  final yValues = ({0, half, niceMax}).toList()..sort();

  final plotWidth = _contentWidth - 46;
  final spacing = n > 1 ? plotWidth / (n - 1) : plotWidth;
  final barWidth = math.min(18.0, spacing * 0.7);

  return pw.SizedBox(
    height: 180,
    width: _contentWidth,
    child: pw.Chart(
      grid: pw.CartesianGrid(
        xAxis: pw.FixedAxis.fromStrings(
          labels,
          textStyle: pw.TextStyle(color: _muted, fontSize: 8),
          angle: labels.length > 12 ? 1.0 : 0,
        ),
        yAxis: pw.FixedAxis(
          yValues,
          format: (value) => _compactCurrency(value),
          textStyle: pw.TextStyle(color: _muted, fontSize: 8),
          divisions: true,
          divisionsColor: _line,
          color: _line,
        ),
      ),
      datasets: [
        pw.BarDataSet(
          data: [
            for (var i = 0; i < n; i++)
              pw.PointChartValue(i.toDouble(), values[i].toDouble()),
          ],
          color: _primary,
          width: barWidth,
          drawPoints: false,
        ),
      ],
    ),
  );
}

int _niceCeil(int value) {
  if (value <= 0) return 1000;
  final exp = (math.log(value) / math.ln10).floor();
  final base = math.pow(10, exp).toInt();
  final fraction = value / base;
  int nice;
  if (fraction <= 1) {
    nice = 1;
  } else if (fraction <= 2) {
    nice = 2;
  } else if (fraction <= 5) {
    nice = 5;
  } else {
    nice = 10;
  }
  return nice * base;
}

String _compactCurrency(num value) {
  if (value >= 1000000) {
    final millions = value / 1000000;
    return '${millions == millions.roundToDouble() ? millions.toStringAsFixed(0) : millions.toStringAsFixed(1)}jt';
  }
  if (value >= 1000) {
    final thousands = value / 1000;
    return '${thousands == thousands.roundToDouble() ? thousands.toStringAsFixed(0) : thousands.toStringAsFixed(1)}rb';
  }
  return value.toStringAsFixed(0);
}

class _AggBucket {
  _AggBucket({required this.label, required this.start, required this.endExclusive});

  final String label;
  final DateTime start;
  final DateTime endExclusive;
  int omzet = 0;
  int trx = 0;
  int items = 0;
  int profit = 0;
  int cashIn = 0;
  int cashOut = 0;
}

List<_AggBucket> _buildBuckets(AppStore store, ReportPeriod period) {
  final result = <_AggBucket>[];

  if (period.type == ReportPeriodType.daily) {
    for (var h = 0; h < 24; h += 2) {
      result.add(
        _AggBucket(
          label: h.toString().padLeft(2, '0'),
          start: DateTime(period.start.year, period.start.month, period.start.day, h),
          endExclusive: DateTime(period.start.year, period.start.month, period.start.day, h + 2),
        ),
      );
    }
  } else {
    final dayBuckets = store.dailyAggregatesBetween(
      period.start,
      period.endExclusive,
    );
    if (period.type == ReportPeriodType.weekly ||
        period.type == ReportPeriodType.monthly) {
      for (final day in dayBuckets) {
        result.add(
          _AggBucket(
            label: '${day.date.day}',
            start: day.date,
            endExclusive: DateTime(day.date.year, day.date.month, day.date.day + 1),
          ),
        );
      }
    } else {
      final grouped = <String, _AggBucket>{};
      for (final day in dayBuckets) {
        final key = '${day.date.year}-${day.date.month}';
        final bucket = grouped.putIfAbsent(
          key,
          () => _AggBucket(
            label: DateFormatter.months[day.date.month - 1],
            start: DateTime(day.date.year, day.date.month, 1),
            endExclusive: DateTime(day.date.year, day.date.month + 1, 1),
          ),
        );
        bucket.omzet += day.omzet;
        bucket.trx += day.transactions;
        bucket.items += day.items;
        bucket.profit += day.profit;
        bucket.cashIn += day.cashIn;
        bucket.cashOut += day.cashOut;
      }
      result.addAll(grouped.values);
    }
  }

  for (final bucket in result) {
    bucket.omzet = store.omzetBetween(bucket.start, bucket.endExclusive);
    bucket.trx = store.transactionCountBetween(bucket.start, bucket.endExclusive);
    bucket.items = store.itemsSoldBetween(bucket.start, bucket.endExclusive);
    bucket.profit = store.estimatedProfitBetween(bucket.start, bucket.endExclusive);
    bucket.cashIn = store.cashInBetween(bucket.start, bucket.endExclusive);
    bucket.cashOut = store.cashOutBetween(bucket.start, bucket.endExclusive);
  }

  return result;
}

pw.Widget _buildCategorySection(List<MapEntry<String, int>> categories) {
  final total = categories.fold<int>(0, (s, c) => s + c.value);
  final used = categories.take(8).toList();

  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _gutter,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 130,
          height: 130,
          child: pw.Chart(
            grid: pw.PieGrid(),
            datasets: [
              for (var i = 0; i < used.length; i++)
                pw.PieDataSet(
                  value: used[i].value.toDouble(),
                  color: _palette[i % _palette.length],
                  legendPosition: pw.PieLegendPosition.none,
                ),
            ],
          ),
        ),
        pw.SizedBox(width: 22),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < used.length; i++) ...[
                pw.Row(
                  children: [
                    pw.Container(
                      width: 9,
                      height: 9,
                      decoration: pw.BoxDecoration(
                        color: _palette[i % _palette.length],
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                    ),
                    pw.SizedBox(width: 7),
                    pw.Expanded(
                      child: pw.Text(
                        used[i].key,
                        style: pw.TextStyle(color: _ink, fontSize: 9),
                      ),
                    ),
                    pw.Text(
                      '${total > 0 ? (used[i].value * 100 / total).toStringAsFixed(0) : 0}%',
                      style: pw.TextStyle(
                        color: _secondary,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Text(
                      _money(used[i].value),
                      style: pw.TextStyle(color: _ink, fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 7),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildTopProducts(List<MapEntry<Product, int>> topProducts) {
  final maxQty = topProducts.first.value;

  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    child: pw.Column(
      children: [
        for (final entry in topProducts) ...[
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  entry.key.name,
                  maxLines: 1,
                  style: pw.TextStyle(color: _ink, fontSize: 10),
                ),
              ),
              pw.Text(
                '${entry.value} pcs',
                style: pw.TextStyle(
                  color: _secondary,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Stack(
            children: [
              pw.Container(
                height: 9,
                decoration: pw.BoxDecoration(
                  color: _gutter,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
              ),
              pw.Positioned(
                left: 0,
                top: 0,
                child: pw.Container(
                  height: 9,
                  width: (_contentWidth - 6) * (maxQty > 0 ? entry.value / maxQty : 0),
                  decoration: pw.BoxDecoration(
                    color: _primary,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
        ],
      ],
    ),
  );
}

pw.Widget _buildDetailTable(AppStore store, ReportPeriod period) {
  final buckets = _buildBuckets(store, period);
  final headers = ['Periode', 'Transaksi', 'Item', 'Omzet', 'Laba', 'Kas Masuk', 'Kas Keluar'];
  final data = <List<String>>[
    for (final b in buckets)
      [
        b.label,
        '${b.trx}',
        '${b.items}',
        _money(b.omzet),
        _money(b.profit),
        _money(b.cashIn),
        _money(b.cashOut),
      ],
  ];

  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 12),
    child: pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        color: _muted,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: pw.TextStyle(color: _ink, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: _gutter),
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: _line, width: 0.5),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
    ),
  );
}

pw.Widget _buildCashFlow(AppStore store, ReportPeriod period) {
  final cashIn = store.cashInBetween(period.start, period.endExclusive);
  final cashOut = store.cashOutBetween(period.start, period.endExclusive);
  final net = cashIn - cashOut;

  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 10),
    child: pw.TableHelper.fromTextArray(
      headers: ['Kas Masuk', 'Kas Keluar', 'Selisih'],
      data: [
        [
          _money(cashIn),
          _money(cashOut),
          '${net >= 0 ? '+' : '-'} ${_money(net.abs())}',
        ],
      ],
      headerStyle: pw.TextStyle(
        color: _muted,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: pw.TextStyle(
        color: _ink,
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(color: _gutter),
      cellAlignments: const {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
      },
      border: pw.TableBorder.all(color: _line, width: 0.6),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 6),
    ),
  );
}

pw.Widget _buildTimestamp(ReportPeriod period) {
  final now = DateTime.now();
  return pw.Column(
    children: [
      pw.Divider(height: 1, thickness: 0.6, color: _line),
      pw.SizedBox(height: 10),
      pw.Text(
        'Dokumen dibuat otomatis pada ${DateFormatter.when(now)} '
        'oleh Aplikasi Kasir Easy.',
        style: pw.TextStyle(color: _muted, fontSize: 8),
      ),
    ],
  );
}