import 'package:flutter/material.dart';

import '../../../core/data/app_store.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/cart_item.dart';
import '../models/order.dart';

Future<void> showReceiptPreview(
  BuildContext context, {
  required Order order,
  required AppStore store,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ReceiptPreviewDialog(order: order, store: store),
  );
}

class ReceiptPreviewDialog extends StatefulWidget {
  const ReceiptPreviewDialog({
    super.key,
    required this.order,
    required this.store,
  });

  final Order order;
  final AppStore store;

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  bool _wide = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = <Widget>[];
    lines.addAll(_header());
    lines.add(const _Divider());
    for (final item in widget.order.items) {
      lines.addAll(_itemLines(item));
    }
    lines.add(const _Divider());
    lines.addAll(_moneyLines());
    lines.add(const _Divider());
    lines.addAll(_paymentLines());
    lines.add(const _Divider());
    lines.add(const _CenterLine('Terima kasih, datang kembali!'));

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pratinjau Struk',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('58mm')),
                      ButtonSegment(value: true, label: Text('80mm')),
                    ],
                    selected: {_wide},
                    onSelectionChanged: (selection) =>
                        setState(() => _wide = selection.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Center(
                    child: Container(
                      width: _wide ? 320 : 232,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...lines,
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _mockAction('Struk dibagikan (mock)'),
                      icon: const Icon(Icons.share),
                      label: const Text('Bagikan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _mockAction('Struk dicetak (mock)'),
                      icon: const Icon(Icons.print),
                      label: const Text('Cetak'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _header() {
    final shift = widget.store.activeShift;
    return [
      const _CenterLine('AKWARIAH'),
      const _CenterLine('Jl. Merdeka No. 45, Jakarta'),
      const _CenterLine('Telp: 021-555-0123'),
      const SizedBox(height: 6),
      _Row(
        left: 'No. ${widget.order.id}',
        right: shift == null ? '-' : shift.id,
      ),
      _Row(
        left: 'Tgl',
        right: DateFormatter.when(widget.order.createdAt),
      ),
      _Row(
        left: 'Shift',
        right: shift?.id ?? 'Tutup',
      ),
    ];
  }

  List<Widget> _itemLines(CartItem item) {
    return [
      _Row(
        left: '${item.quantity} ${item.product.name}',
        leftBold: true,
      ),
      _Row(
        left: '   @${CurrencyFormatter.formatIDR(item.unitPrice)} '
            '${item.isWholesale ? '(grosir)' : '(ecer)'}',
        right: CurrencyFormatter.formatIDR(item.subtotal),
      ),
    ];
  }

  List<Widget> _moneyLines() {
    final order = widget.order;
    return [
      _Row(left: 'Subtotal', right: CurrencyFormatter.formatIDR(order.itemsTotal)),
      _Row(
        left: 'Diskon',
        right: CurrencyFormatter.formatIDR(order.discount),
      ),
      _Row(
        left: 'TOTAL',
        leftBold: true,
        right: CurrencyFormatter.formatIDR(order.total),
        rightBold: true,
      ),
    ];
  }

  List<Widget> _paymentLines() {
    final order = widget.order;
    return [
      _Row(left: 'Tunai', right: CurrencyFormatter.formatIDR(order.paidAmount)),
      _Row(left: 'Kembalian', right: CurrencyFormatter.formatIDR(order.change)),
    ];
  }

  void _mockAction(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.left,
    this.right,
    this.leftBold = false,
    this.rightBold = false,
  });

  final String left;
  final String? right;
  final bool leftBold;
  final bool rightBold;

  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
      height: 1.5,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              left,
              style: style.copyWith(
                fontWeight: leftBold ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
          if (right != null)
            Expanded(
              flex: 2,
              child: Text(
                right!,
                textAlign: TextAlign.right,
                style: style.copyWith(
                  fontWeight: rightBold ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CenterLine extends StatelessWidget {
  const _CenterLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '----------------------------------------',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'monospace', fontSize: 10),
      ),
    );
  }
}