import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_navigation_drawer.dart';
import '../../../core/widgets/section_header.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  String _query = '';

  bool get _hasQuery => _query.trim().isNotEmpty;

  List<_GuideSection> get _filteredSections {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _GuideSection.all;
    return _GuideSection.all.where((section) => section.matches(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _filteredSections;

    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: widget.selectedDestination,
        onDestinationSelected: widget.onDestinationSelected,
      ),
      appBar: AppBar(
        title: const Text('Panduan Penggunaan'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Cari topik panduan...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                const _IntroCard(),
                const SizedBox(height: 16),
                const SectionHeader(title: 'Mulai Cepat'),
                const SizedBox(height: 8),
                const _QuickStartCard(),
                const SizedBox(height: 16),
                SectionHeader(
                  title: _hasQuery
                      ? 'Panduan (${sections.length})'
                      : 'Panduan Lengkap',
                ),
                const SizedBox(height: 8),
                if (sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 44,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ada topik yang cocok',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final section in sections) ...[
                    _SectionCard(
                      section: section,
                      initiallyExpanded: _hasQuery,
                    ),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 8),
                const SectionHeader(title: 'FAQ & Tips'),
                const SizedBox(height: 8),
                const _FaqCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection {
  const _GuideSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.steps,
    this.tips = const [],
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> steps;
  final List<String> tips;

  bool matches(String query) {
    bool hit(String? text) => text != null && text.toLowerCase().contains(query);
    if (hit(title) || hit(description)) return true;
    return steps.any(hit) || tips.any(hit);
  }

  static const List<_GuideSection> all = [
    _GuideSection(
      icon: Icons.point_of_sale,
      title: 'Kasir (POS)',
      description:
          'Layar utama untuk melakukan penjualan tiap hari, cocok untuk '
          'tablet maupun ponsel.',
      steps: [
        'Cari produk lewat kolom pencarian nama atau barcode di bagian atas.',
        'Atau pindai barcode produk dengan ikon pemindai di ujung kanan kolom '
            'pencarian.',
        'Ketuk kartu produk untuk memasukkannya ke keranjang. Jumlah bisa '
            'ditambah/dikurangi lewat tombol + dan - pada item keranjang.',
        'Item berlabel "grosir" berarti sudah memenuhi minimal qty sehingga '
            'harga otomatis menjadi harga grosir.',
        'Ketuk "Bayar", isi uang diterima. Bisa tekan "Uang Pas" atau nominal '
            'cepat Rp20.000 / Rp50.000 / Rp100.000, lalu tambahkan diskon '
            'jika perlu.',
        'Aplikasi menampilkan kembalian, lalu pratinjau struk yang bisa '
            'dibagikan atau dicetak (lebar 58 mm / 80 mm).',
      ],
      tips: [
        'Stok produk otomatis berkurang setiap transaksi selesai.',
        'Produk dengan stok 0 tidak bisa ditambahkan ke keranjang.',
        'Transaksi saat shift aktif ikut dihitung pada Shift Kasir.',
      ],
    ),
    _GuideSection(
      icon: Icons.inventory_2_outlined,
      title: 'Inventori',
      description:
          'Kelola daftar produk, stok, harga, barcode, hingga foto produk.',
      steps: [
        'Buka menu Inventori, lalu ketuk ikon + di kanan atas untuk menambah '
            'produk.',
        'Isi nama produk, kategori, harga ecer, dan harga modal (untuk '
            'perhitungan laba).',
        'Opsi grosir: isi harga grosir dan minimal qty grosir — kedua kolom '
            'harus diisi bersamaan agar aktif.',
        'Isi stok awal, barcode, tanggal kedaluwarsa, dan nomor batch jika ada.',
        'Pilih foto produk dari galeri atau kamera, lalu ketuk "Simpan Produk".',
        'Ketuk kartu produk untuk mengedit, atau ikon hapus untuk menghapus '
            'produk.',
      ],
      tips: [
        'Stok 0 ditandai "Habis", sedangkan stok 1-5 ditandai warna oranye.',
        'Produk dengan kedaluwarsa kurang dari 14 hari ditandai peringatan '
            '"Mendekati kedaluwarsa".',
        'Menghapus produk juga otomatis mengeluarkan produk dari keranjang.',
      ],
    ),
    _GuideSection(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Kas Masuk / Keluar',
      description:
          'Catat semua pemasukan dan pengeluaran uang di luar penjualan.',
      steps: [
        'Buka menu Kas Masuk / Keluar, lalu ketuk ikon + untuk mencatat.',
        'Pilih jenis "Masuk" atau "Keluar", lalu isi nominal (Rp).',
        'Pilih kategori sesuai transaksi (Penjualan, Belanja Stok, '
            'Biaya Operasional, Gaji, dan lainnya).',
        'Tambahkan catatan ringkas, lalu ketuk "Simpan Catatan".',
        'Gunakan segmen "Kas Masuk" / "Kas Keluar" di atas untuk menyaring '
            'daftar.',
      ],
      tips: [
        'Penjualan POS dan pembayaran hutang/piutang tercatat otomatis di sini.',
        'Total penerimaan dan pengeluaran terlihat ringkas di kartu total.',
      ],
    ),
    _GuideSection(
      icon: Icons.receipt_long_outlined,
      title: 'Hutang & Piutang',
      description:
          'Pantau piutang dari pelanggan dan hutang ke supplier, lengkap '
          'dengan jatuh tempo.',
      steps: [
        'Buka menu Hutang & Piutang, lalu pilih tab "Piutang" atau "Hutang".',
        'Ketuk ikon + untuk mencatat, isi nama pelanggan/supplier, nominal, '
            'jatuh tempo (opsional), dan catatan.',
        'Ketuk kartu tagihan untuk melihat detail, riwayat pembayaran, dan sisa.',
        'Isi nominal bayar lalu ketuk "Bayar Sekarang" (lunas) atau '
            '"Bayar Sebagian" untuk pembayaran cicilan.',
        'Tagihan lunas otomatis berpindah ke bawah dengan label "Lunas".',
      ],
      tips: [
        'Tagihan yang melewati jatuh tempo ditandai merah "Jatuh tempo".',
        'Pembayaran piutang/hutang otomatis tercatat ke Kas Masuk / Keluar.',
        'Tidak bisa membayar melebihi sisa tagihan.',
      ],
    ),
    _GuideSection(
      icon: Icons.history,
      title: 'Shift Kasir',
      description:
          'Buka dan tutup shift kasir untuk mencocokkan kas pada tiap '
          'pergantian jaga.',
      steps: [
        'Buka menu Shift Kasir. Jika belum ada shift aktif, isi "Kas awal" '
            'lalu ketuk "Buka Shift".',
        'Selama shift aktif, lakukan transaksi seperti biasa di Kasir (POS).',
        'Saat selesai, ketuk "Tutup Shift" dan isi "Kas akhir" sesuai hitungan '
            'uang fisik di laci kas.',
        'Aplikasi menghitung kas terkira (kas awal + penjualan) lalu '
            'membandingkannya dengan kas akhir.',
        'Hasilnya ditampilkan: Kondang (pas), Surplus, atau Defisit.',
        'Semua shift yang sudah ditutup tercatat di "Riwayat Shift".',
      ],
      tips: [
        'Buka shift baru setiap pergantian petugas agar rekapan kas rapi.',
        'Selisih surplus/defisit berguna untuk audit uang laci kas.',
        'Kas awal bisa diisi 0 jika tidak ada uang awal di laci.',
      ],
    ),
    _GuideSection(
      icon: Icons.summarize_outlined,
      title: 'Laporan & Unduh PDF',
      description:
          'Pantau omzet, laba, arus kas, dan produk terlaris, lalu unduh '
          'sebagai laporan PDF.',
      steps: [
        'Buka menu Laporan. Pilih tanggal dengan ikon kalender untuk melihat '
            'data harian.',
        'Periksa ringkasan omzet, estimasi laba, jumlah transaksi, dan item '
            'terjual.',
        'Lihat selisih arus kas masuk dan keluar pada kartu "Arus Kas".',
        'Cek produk terlaris pada tanggal tersebut di kartu "Produk Terlaris".',
        'Ketuk ikon unduh di kanan atas untuk membuat laporan PDF.',
        'Pilih jenis (Harian, Mingguan, Bulanan, Kuartal, Tahunan) dan periode, '
            'lalu ketuk "Unduh PDF" dan simpan/cetak dari pratinjau.',
      ],
      tips: [
        'Estimasi laba hanya muncul jika produk punya harga modal.',
        'Laporan PDF memuat omzet, laba, arus kas, dan produk terlaris per '
            'periode.',
      ],
    ),
    _GuideSection(
      icon: Icons.print_outlined,
      title: 'Printer Termal Bluetooth',
      description:
          'Cetak struk langsung ke printer thermal 58mm atau 80mm tanpa '
          'perlu aplikasi cetak Android.',
      steps: [
        'Nyalakan printer, lalu pairingkan lewat pengaturan Bluetooth ponsel '
            '(tekan "Pengaturan BT" untuk membuka pengaturan sistem).',
        'Buka menu Printer Termal, tekan "Cari Printer", lalu pilih printer '
            'yang muncul.',
        'Uji koneksi dengan ikon cetak pada printer yang dipilih. Pastikan '
            'struk keluar sesuai lebar kertas printer.',
        'Pilih lebar kertas 58mm atau 80mm dan jumlah salinan sesuai '
            'kebutuhan.',
        'Aktifkan "Cetak otomatis setelah pembayaran" agar struk langsung '
            'keluar begitu pembayaran selesai.',
        'Cetak ulang kapan saja dari pratinjau struk lewat tombol "Cetak ke '
            '...".',
      ],
      tips: [
        'Hanya perangkat Android yang bisa mencetak lewat Bluetooth.',
        'Bila printer gagal merespons, transaksi tetap tersimpan. Gunakan '
            '"Coba Lagi" atau cetak ulang dari pratinjau struk.',
        'Karakter di luar latin-1 yang tidak didukung printer akan tampil '
            'sebagai tanda tanya.',
      ],
    ),
    _GuideSection(
      icon: Icons.settings_outlined,
      title: 'Pengaturan & Cadangan Data',
      description:
          'Atur identitas toko untuk struk dan laporan, serta amankan data '
          'dengan cadangan.',
      steps: [
        'Buka menu Pengaturan untuk mengisi nama toko, alamat, dan telepon. '
            'Identitas ini dipakai di kepala struk dan laporan PDF.',
        'Pengaturan Printer Termal juga tersedia di menu Pengaturan, menampilkan '
            'printer yang sedang dipilih dan lebar kartasnya.',
        'Isi pesan bawah struk (opsional), misalnya syarat dan ketentuan toko.',
        'Gunakan "Cadangkan Data" untuk menyimpan seluruh data ke file .json, '
            'lalu simpan/bagikan ke tempat aman.',
        'Gunakan "Pulihkan dari File" untuk memuat data dari file cadangan. '
            'Seluruh data saat ini akan digantikan isi file tersebut.',
      ],
      tips: [
        'Lakukan cadangan berkala, misalnya setiap akhir minggu.',
        'Perubahan identitas toko langsung berlaku pada struk dan laporan '
            'berikutnya.',
      ],
    ),
  ];
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 30,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aplikasi Kasir Easy',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Panduan lengkap penggunaan aplikasi kasir untuk toko '
                    'dan mini-market. Buka menu melalui tombol hamburger di '
                    'pojok kiri atas, atau cari topik di kolom di atas.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  const _QuickStartCard();

  static const _steps = [
    'Buka menu lewat tombol hamburger di pojok kiri atas.',
    'Buka Shift Kasir, isi kas awal, lalu ketuk "Buka Shift".',
    'Buka Inventori, ketuk +, dan tambahkan produk yang akan dijual.',
    'Kembali ke Kasir (POS), pilih produk atau scan barcode, lalu "Bayar".',
    'Cek hasil penjualan dan unduh laporannya lewat menu Laporan.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == _steps.length - 1 ? 0 : 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _steps[i],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    this.initiallyExpanded = false,
  });

  final _GuideSection section;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: theme.colorScheme.primary,
        collapsedIconColor: theme.colorScheme.primary,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(section.icon, color: theme.colorScheme.primary, size: 22),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            section.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        subtitle: Text(
          section.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'Langkah-langkah',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < section.steps.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == section.steps.length - 1 ? 0 : 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.steps[i],
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          if (section.tips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Tips',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            for (final tip in section.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: AppTheme.warningOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard();

  static const _faqs = [
    (
      'Apakah data aman?',
      'Semua data tersimpan otomatis di perangkat secara offline. '
          'Tidak memerlukan koneksi internet untuk menjalankan aplikasi.',
    ),
    (
      'Mengapa stok berubah otomatis?',
      'Setiap transaksi selesai, stok produk otomatis dikurangi sesuai jumlah '
          'terjual. Cek atau sesuaikan stok di menu Inventori.',
    ),
    (
      'Kapan harga grosir berlaku?',
      'Harga grosir berlaku otomatis saat jumlah sebuah produk di keranjang '
          'sudah mencapai minimal qty grosir yang diatur saat menambah produk.',
    ),
    (
      'Apakah pembayaran hutang/piutang masuk ke kas?',
      'Ya. Pembayaran piutang tercatat sebagai Kas Masuk dan pembayaran '
          'hutang sebagai Kas Keluar, sehingga kas selalu sinkron.',
    ),
    (
      'Bagaimana cara membuat laporan PDF?',
      'Buka menu Laporan, ketuk ikon unduh di kanan atas, pilih jenis dan '
          'periode, lalu ketuk "Unduh PDF".',
    ),
    (
      'Apa itu Surplus dan Defisit di Shift Kasir?',
      'Selisih antara kas akhir dengan kas terkira. Surplus berarti uang '
          'lebih banyak dari seharusnya, defisit berarti kurang.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _faqs.length; i++) ...[
              if (i > 0)
                Divider(height: 24, color: theme.colorScheme.outlineVariant),
              _FaqItem(question: _faqs[i].$1, answer: _faqs[i].$2),
            ],
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: theme.textTheme.bodySmall?.copyWith(
            height: 1.4,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}