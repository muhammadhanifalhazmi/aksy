import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/data/app_store.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../printer/models/bluetooth_printer_device.dart';
import '../../printer/models/printer_settings.dart';
import '../../printer/services/print_receipt_action.dart';
import '../../printer/services/thermal_printer_service.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../services/receipt_layout.dart';
import '../services/receipt_pdf_generator.dart';

Future<void> showReceiptPreview(
  BuildContext context, {
  required Order order,
  required AppStore store,
  ThermalPrinterService? printerService,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ReceiptPreviewDialog(
      order: order,
      store: store,
      printerService: printerService,
    ),
  );
}

class ReceiptPreviewDialog extends StatefulWidget {
  const ReceiptPreviewDialog({
    super.key,
    required this.order,
    required this.store,
    this.printerService,
  });

  final Order order;
  final AppStore store;
  final ThermalPrinterService? printerService;

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  bool _wide = false;
  bool _busy = false;
  bool _thermalBusy = false;

  ThermalPrinterService get _printer =>
      widget.printerService ?? ThermalPrinterService();

  PrinterSettings get _printerSettings => widget.store.printer;

  bool get _canPrintThermal =>
      _printer.isSupported && _printerSettings.isConfigured;

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
    for (final text in receiptFooterLines(widget.store.settings.footer)) {
      lines.add(_CenterLine(text));
    }
    lines.add(const SizedBox(height: 10));
    lines.add(const _BrandBlock());

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
                      child: Stack(
                        children: [
                          const Positioned.fill(child: _BrandWatermark()),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...lines,
                              const SizedBox(height: 8),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_canPrintThermal) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _thermalBusy ? null : _printThermal,
                    icon: _thermalBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined),
                    label: Text(
                      'Cetak ke ${_printerSettings.deviceName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _share,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share),
                      label: const Text('Bagikan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _print,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print),
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
    final settings = widget.store.settings;
    return [
      _CenterLine(settings.name),
      if (settings.address.isNotEmpty) _CenterLine(settings.address),
      if (settings.phone.isNotEmpty) _CenterLine(settings.phone),
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

  Future<void> _printThermal() async {
    if (_thermalBusy) return;
    setState(() => _thermalBusy = true);
    try {
      await _printer.printReceipt(
        settings: _printerSettings,
        store: widget.store,
        order: widget.order,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Struk dikirim ke ${_printerSettings.deviceName}'),
        ),
      );
    } on PrinterException catch (error) {
      if (!mounted) return;
      await showPrintFailureDialog(
        context,
        message: error.message,
        onRetry: _printThermal,
      );
    } finally {
      if (mounted) setState(() => _thermalBusy = false);
    }
  }

  Future<void> _share() => _exportReceipt(isPrint: false);

  Future<void> _print() => _exportReceipt(isPrint: true);

  Future<void> _exportReceipt({required bool isPrint}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await generateReceiptPdf(
        order: widget.order,
        store: widget.store,
        wide: _wide,
      );
      if (!mounted) return;
      final name = 'struk-${widget.order.id}.pdf';
      if (isPrint) {
        await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk dikirim ke dialog cetak')),
        );
      } else {
        await Printing.sharePdf(bytes: bytes, filename: name);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk PDF dibagikan')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPrint
                ? 'Gagal mencetak struk'
                : 'Tidak ada aplikasi untuk membagikan struk',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Image.asset(
          receiptBrandAsset,
          width: 46,
          height: 46,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        Text(
          receiptBrandName,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          receiptBrandTagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _BrandWatermark extends StatelessWidget {
  const _BrandWatermark();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Transform.rotate(
          angle: -0.5,
          child: Opacity(
            opacity: 0.07,
            child: Image.asset(
              receiptBrandAsset,
              width: 190,
              height: 190,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
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