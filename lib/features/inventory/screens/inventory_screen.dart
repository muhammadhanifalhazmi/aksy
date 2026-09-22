import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/app_store.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../pos/models/product.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final products = store.products
        .where(
          (p) =>
              _query.isEmpty ||
              p.name.toLowerCase().contains(_query.toLowerCase()) ||
              (p.barcode ?? '').contains(_query),
        )
        .toList()
      ..sort((a, b) => (b.stock == 0 ? 1 : 0).compareTo(a.stock == 0 ? 1 : 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventori'),
        actions: [
          IconButton(
            onPressed: () => _showProductForm(context, store, product: null),
            tooltip: 'Tambah Produk',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Cari nama atau barcode...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const _EmptyInventory()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _InventoryCard(
                        product: product,
                        onTap: () => _showProductForm(
                          context,
                          store,
                          product: product,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProductForm(
    BuildContext context,
    AppStore store, {
    required Product? product,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProductFormSheet(
        store: store,
        product: product,
      ),
    );
  }
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada produk yang cocok',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final out = product.stock <= 0;
    final warning = product.isExpiringSoon();
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(product.icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _StockChip(stock: product.stock, out: out),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    if (product.barcode != null)
                      Text(
                        'Barcode: ${product.barcode}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.formatIDR(product.price),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (product.hasWholesaleTier)
                      Text(
                        'Grosir ${CurrencyFormatter.formatIDR(product.wholesalePrice!)} '
                        'min ${product.minWholesaleQty} pcs',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (warning) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Mendekati kedaluwarsa '
                        '${DateFormatter.reportDate(product.expiryDate!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({required this.stock, required this.out});

  final int stock;
  final bool out;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = out
        ? theme.colorScheme.error
        : stock <= 5
            ? Colors.orange
            : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        out ? 'Habis' : 'Stok $stock',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({required this.store, this.product});

  final AppStore store;
  final Product? product;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _category;
  late final TextEditingController _wholesalePrice;
  late final TextEditingController _minWholesaleQty;
  late final TextEditingController _costPrice;
  late final TextEditingController _barcode;
  late final TextEditingController _stock;
  late final TextEditingController _batchNumber;
  DateTime? _expiryDate;
  IconData _icon = Icons.inventory_2;

  bool get _hasWholesale => _wholesalePrice.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(text: p?.price.toString() ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _wholesalePrice = TextEditingController(
      text: p?.wholesalePrice?.toString() ?? '',
    );
    _minWholesaleQty = TextEditingController(
      text: p?.minWholesaleQty?.toString() ?? '',
    );
    _costPrice = TextEditingController(text: p?.costPrice?.toString() ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _stock = TextEditingController(text: p?.stock.toString() ?? '0');
    _batchNumber = TextEditingController(text: p?.batchNumber ?? '');
    _expiryDate = p?.expiryDate;
    _icon = p?.icon ?? _icon;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _category.dispose();
    _wholesalePrice.dispose();
    _minWholesaleQty.dispose();
    _costPrice.dispose();
    _barcode.dispose();
    _stock.dispose();
    _batchNumber.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final intended = _wholesalePrice.text.trim().isEmpty
        ? null
        : int.tryParse(_wholesalePrice.text.trim());
    final minQty = _minWholesaleQty.text.trim().isEmpty
        ? null
        : int.tryParse(_minWholesaleQty.text.trim());
    final validWholesale =
        (intended == null && minQty == null) || (intended != null && minQty != null);
    if (!validWholesale) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harga grosir dan minimal qty harus diisi bersamaan'),
        ),
      );
      return;
    }
    final isNew = widget.product == null;
    final product = Product(
      id: widget.product?.id ?? 'P${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim(),
      price: int.parse(_price.text.trim()),
      category: _category.text.trim().isEmpty ? 'Umum' : _category.text.trim(),
      icon: _icon,
      wholesalePrice: intended,
      minWholesaleQty: minQty,
      costPrice: int.tryParse(_costPrice.text.trim()),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      stock: int.tryParse(_stock.text.trim()) ?? 0,
      expiryDate: _expiryDate,
      batchNumber: _batchNumber.text.trim().isEmpty
          ? null
          : _batchNumber.text.trim(),
    );
    if (isNew) {
      widget.store.addProduct(product);
    } else {
      widget.store.updateProduct(product);
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isNew ? 'Produk ditambahkan' : 'Produk diperbarui')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.product == null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isNew ? 'Tambah Produk' : 'Edit Produk',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nama produk',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Harga ecer (Rp)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final value = int.tryParse(v ?? '');
                          return (value == null || value <= 0)
                              ? 'Harga tidak valid'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costPrice,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Harga modal (Rp)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _wholesalePrice,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Harga grosir (Rp)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minWholesaleQty,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Min qty grosir',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_hasWholesale)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Grosir aktif: pembeli otomatis kena harga '
                      '${CurrencyFormatter.formatIDR(int.parse(_wholesalePrice.text))} '
                      'saat qty >= ${_minWholesaleQty.text}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Stok awal',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _barcode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tanggal kedaluwarsa',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _expiryDate == null
                                ? 'Pilih tanggal'
                                : DateFormatter.reportDate(_expiryDate!),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _batchNumber,
                        decoration: const InputDecoration(
                          labelText: 'No. Batch',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isNew ? 'Simpan Produk' : 'Perbarui Produk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}