import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/pos/models/product.dart';
import '../utils/currency_formatter.dart';

Future<Product?> showBarcodeScanner(
  BuildContext context, {
  required List<Product> products,
}) {
  return showDialog<Product?>(
    context: context,
    builder: (_) => _BarcodeScannerDialog(products: products),
  );
}

class _BarcodeScannerDialog extends StatefulWidget {
  const _BarcodeScannerDialog({required this.products});

  final List<Product> products;

  @override
  State<_BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<_BarcodeScannerDialog> {
  final _controller = TextEditingController();
  bool _scanning = false;
  String? _error;

  List<Product> get _withBarcode =>
      widget.products.where((p) => p.barcode != null).toList();

  Product? _resolve(String value) {
    final code = value.trim();
    if (code.isEmpty) return null;
    for (final product in widget.products) {
      if (product.barcode != null && product.barcode == code) return product;
    }
    return null;
  }

  Future<void> _scan() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _scanning) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final product = _resolve(code);
    setState(() => _scanning = false);
    if (product != null) {
      Navigator.of(context).pop(product);
    } else {
      setState(() => _error = 'Produk dengan barcode $code tidak ditemukan');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Scan Barcode'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Kode barcode',
                hintText: 'contoh: 8991001234567',
                prefixIcon: const Icon(Icons.qr_code_scanner),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _scan(),
            ),
            const SizedBox(height: 10),
            if (_scanning)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Memindai...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final product in _withBarcode.take(3))
                    ActionChip(
                      avatar: Icon(
                        product.icon,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text(product.barcode!),
                      onPressed: () {
                        _controller.text = product.barcode!;
                        _scan();
                      },
                    ),
                ],
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _scanning ? null : _scan,
          icon: const Icon(Icons.center_focus_strong),
          label: const Text('Simulasi Scan'),
        ),
      ],
    );
  }
}

String barcodePriceHint(Product product) {
  if (!product.hasWholesaleTier) return CurrencyFormatter.formatIDR(product.price);
  return '${CurrencyFormatter.formatIDR(product.price)} / '
      'grosir ${CurrencyFormatter.formatIDR(product.wholesalePrice!)} '
      'min ${product.minWholesaleQty}';
}