import '../../../core/data/app_store.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../debt/models/debt.dart';

class StoreContext {
  const StoreContext._();

  static const int lowStockThreshold = 5;
  static const int maxProductsInContext = 60;

  static const String systemInstruction = '''
Kamu adalah asisten analis untuk aplikasi kasir (POS) berbahasa Indonesia.
Tugasmu membantu pemilik toko memahami data penjualan, stok, kas, dan hutang piutang.

Aturan:
1. Jawab dalam Bahasa Indonesia yang singkat, jelas, dan ramah.
2. Semua nominal uang ditulis dalam Rupiah, contoh: Rp 125.000.
3. Gunakan HANYA angka yang ada di KONTEKS DATA. Jika datanya tidak tersedia,
   katakan dengan jujur apa yang tidak ada. Jangan mengarang angka.
4. Hitung rumus dari angka yang tersedia bila perlu, dan sebutkan angkanya.
5. Jika pengguna menanyakan sesuatu di luar data toko (misalnya cuaca atau resep),
   jawab singkat bahwa kamu hanya membantu data toko.
6. Saran harus singkat, konkret, dan berbasis angka yang ada di konteks.
''';

  static String build(AppStore store) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final buffer = StringBuffer();
    buffer.writeln('# KONTEKS DATA TOKO (${DateFormatter.reportDate(now)})');
    buffer.writeln();
    buffer.writeln('## Hari ini');
    buffer.writeln('- Transaksi: ${store.transactionCountOn(today)}');
    buffer.writeln(
      '- Omzet: ${CurrencyFormatter.formatIDR(store.omzetOn(today))}',
    );
    buffer.writeln('- Item terjual: ${store.itemsSoldOn(today)}');
    buffer.writeln(
      '- Estimasi laba: ${CurrencyFormatter.formatIDR(store.estimatedProfitOn(today))}',
    );
    buffer.writeln(
      '- Kas masuk: ${CurrencyFormatter.formatIDR(store.cashInOn(today))}',
    );
    buffer.writeln(
      '- Kas keluar: ${CurrencyFormatter.formatIDR(store.cashOutOn(today))}',
    );

    buffer.writeln();
    buffer.writeln('## Kemarin');
    buffer.writeln(
      '- Transaksi: ${store.transactionCountOn(yesterday)}, '
      'omzet ${CurrencyFormatter.formatIDR(store.omzetOn(yesterday))}',
    );

    buffer.writeln();
    buffer.writeln('## 7 hari terakhir');
    buffer.writeln(
      '- Transaksi: ${store.transactionCountBetween(weekAgo, today.add(const Duration(days: 1)))}',
    );
    buffer.writeln(
      '- Omzet: ${CurrencyFormatter.formatIDR(store.omzetBetween(weekAgo, today.add(const Duration(days: 1))))}',
    );
    buffer.writeln(
      '- Estimasi laba: ${CurrencyFormatter.formatIDR(store.estimatedProfitBetween(weekAgo, today.add(const Duration(days: 1))))}',
    );

    final shift = store.activeShift;
    buffer.writeln();
    buffer.writeln('## Shift kasir');
    if (shift == null) {
      buffer.writeln('- Tidak ada shift yang sedang dibuka.');
    } else {
      final sales = store.totalSalesSince(shift.openTime);
      buffer.writeln(
        '- Shift ${shift.id} dibuka ${DateFormatter.when(shift.openTime)}',
      );
      buffer.writeln(
        '- Kas awal: ${CurrencyFormatter.formatIDR(shift.startingCash)}',
      );
      buffer.writeln(
        '- Penjualan sejak shift dibuka: ${CurrencyFormatter.formatIDR(sales)}',
      );
      buffer.writeln(
        '- Estimasi kas di laci: ${CurrencyFormatter.formatIDR(shift.startingCash + sales)}',
      );
    }

    final topToday = store.topProductsOn(today, limit: 5);
    buffer.writeln();
    buffer.writeln('## Produk terlaris hari ini');
    if (topToday.isEmpty) {
      buffer.writeln('- Belum ada penjualan hari ini.');
    } else {
      for (final entry in topToday) {
        buffer.writeln('- ${entry.key.name}: ${entry.value} pcs');
      }
    }

    final products = store.products;
    final outOfStock = products.where((p) => p.stock <= 0).toList();
    final lowStock = products
        .where((p) => p.stock > 0 && p.stock <= lowStockThreshold)
        .toList();
    final expiring = products.where((p) => p.isExpiringSoon(14)).toList();

    buffer.writeln();
    buffer.writeln('## Inventori');
    buffer.writeln('- Total produk: ${products.length}');
    buffer.writeln('- Stok habis: ${outOfStock.length}');
    buffer.writeln(
      '- Stok menipis (<= $lowStockThreshold): ${lowStock.length}',
    );
    buffer.writeln('- Kedaluwarsa <= 14 hari: ${expiring.length}');
    if (lowStock.isNotEmpty) {
      buffer.writeln(
        '- Perlu restok: ${lowStock.map((p) => '${p.name} (${p.stock})').join(', ')}',
      );
    }
    if (expiring.isNotEmpty) {
      buffer.writeln(
        '- Segera habiskan: ${expiring.map((p) => p.name).join(', ')}',
      );
    }

    final receivables = store.debts
        .where((d) => d.type == DebtType.receivable && d.remaining > 0)
        .toList();
    final payables = store.debts
        .where((d) => d.type == DebtType.payable && d.remaining > 0)
        .toList();
    final receivableTotal = receivables.fold(0, (sum, d) => sum + d.remaining);
    final payableTotal = payables.fold(0, (sum, d) => sum + d.remaining);
    final overdue = receivables.where((d) => d.isOverdue).toList();

    buffer.writeln();
    buffer.writeln('## Hutang & piutang');
    buffer.writeln(
      '- Total piutang: ${CurrencyFormatter.formatIDR(receivableTotal)} '
      'dari ${receivables.length} pelanggan',
    );
    buffer.writeln(
      '- Total utang: ${CurrencyFormatter.formatIDR(payableTotal)} '
      'dari ${payables.length} pemasok',
    );
    buffer.writeln('- Piutang lewat jatuh tempo: ${overdue.length}');
    if (overdue.isNotEmpty) {
      buffer.writeln(
        '- Terlambat: ${overdue.map((d) => d.partyName).join(', ')}',
      );
    }

    if (products.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Daftar produk');
      for (final product in products.take(maxProductsInContext)) {
        buffer.writeln(
          '- ${product.name} | harga ${CurrencyFormatter.formatIDR(product.price)}'
          ' | stok ${product.stock} | kategori ${product.category}',
        );
      }
      if (products.length > maxProductsInContext) {
        buffer.writeln(
          '- ... dan ${products.length - maxProductsInContext} produk lainnya.',
        );
      }
    }

    return buffer.toString().trimRight();
  }
}
