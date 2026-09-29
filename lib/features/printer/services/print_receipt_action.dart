import 'package:flutter/material.dart';

import '../../../core/data/app_store.dart';
import '../../pos/models/order.dart';
import '../models/bluetooth_printer_device.dart';
import '../services/thermal_printer_service.dart';

Future<bool> printReceiptSilently({
  required BuildContext context,
  required AppStore store,
  required Order order,
  ThermalPrinterService? service,
}) async {
  final printer = service ?? ThermalPrinterService();
  if (!printer.isSupported) {
    debugPrint('print: platform tidak mendukung printer');
    return false;
  }
  final settings = store.printer;
  if (!settings.isConfigured) {
    debugPrint('print: dilewati, printer belum dipilih');
    return false;
  }
  debugPrint(
    'print: kirim struk ${order.id} ke ${settings.deviceName} (${settings.deviceAddress})',
  );
  try {
    await printer.printReceipt(settings: settings, store: store, order: order);
    debugPrint('print: struk ${order.id} terkirim');
    return true;
  } on PrinterException catch (error) {
    debugPrint('print: struk ${order.id} gagal -> ${error.message}');
    return false;
  }
}

Future<void> printReceiptManually({
  required BuildContext context,
  required AppStore store,
  required Order order,
  ThermalPrinterService? service,
}) async {
  final printer = service ?? ThermalPrinterService();
  if (!printer.isSupported) {
    _toast(context, 'Printer Bluetooth hanya tersedia di Android', isError: true);
    return;
  }
  final settings = store.printer;
  if (!settings.isConfigured) {
    _toast(context, 'Belum ada printer yang dipilih di menu Printer Termal', isError: true);
    return;
  }
  try {
    await printer.printReceipt(settings: settings, store: store, order: order);
    if (!context.mounted) return;
    _toast(context, 'Struk dikirim ke ${settings.deviceName}');
  } on PrinterException catch (error) {
    if (!context.mounted) return;
    await showPrintFailureDialog(
      context,
      message: error.message,
      onRetry: () => printReceiptManually(
        context: context,
        store: store,
        order: order,
        service: service,
      ),
    );
  }
}

Future<void> showPrintFailureDialog(
  BuildContext context, {
  required String message,
  VoidCallback? onRetry,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Gagal mencetak'),
      content: Text(
        '$message\n\nTransaksi tetap tersimpan. Struk bisa dicetak ulang dari '
        'pratinjau struk.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Tutup'),
        ),
        if (onRetry != null)
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRetry();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
          ),
      ],
    ),
  );
}

void _toast(BuildContext context, String message, {bool isError = false}) {
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? theme.colorScheme.error : null,
    ),
  );
}
