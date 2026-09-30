import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/data/app_store.dart';
import '../../pos/models/order.dart';
import '../models/bluetooth_printer_device.dart';
import '../services/thermal_printer_service.dart';

Future<PrintOutcome> printReceipt({
  required BuildContext context,
  required AppStore store,
  required Order order,
  ThermalPrinterService? service,
}) async {
  final printer = service ?? ThermalPrinterService();
  if (!printer.isSupported) {
    _log('platform tidak mendukung printer');
    return const PrintOutcome.unsupported();
  }
  final settings = store.printer;
  if (!settings.isConfigured) {
    _log('dilewati, printer belum dipilih');
    return const PrintOutcome.notConfigured();
  }
  _log('kirim struk ke ${settings.deviceName}');
  try {
    await printer.printReceipt(settings: settings, store: store, order: order);
    _log('struk ${order.id} terkirim');
    return const PrintOutcome.success();
  } on PrinterException catch (error) {
    _log('struk ${order.id} gagal -> ${error.message}');
    return PrintOutcome.failure(error.message);
  }
}

void _log(String message) {
  if (kDebugMode) debugPrint('print: $message');
}

Future<bool> printReceiptSilently({
  required BuildContext context,
  required AppStore store,
  required Order order,
  ThermalPrinterService? service,
}) async {
  final outcome = await printReceipt(
    context: context,
    store: store,
    order: order,
    service: service,
  );
  return outcome.printed;
}

enum PrintStatus { printed, failed, unsupported, notConfigured }

class PrintOutcome {
  const PrintOutcome._(this.status, [this.message = '']);

  const PrintOutcome.success() : this._(PrintStatus.printed);

  const PrintOutcome.failure(String message)
    : this._(PrintStatus.failed, message);

  const PrintOutcome.unsupported()
    : this._(PrintStatus.unsupported, 'Printer Bluetooth hanya tersedia di Android');

  const PrintOutcome.notConfigured()
    : this._(
        PrintStatus.notConfigured,
        'Belum ada printer yang dipilih di menu Printer Termal',
      );

  final PrintStatus status;
  final String message;

  bool get printed => status == PrintStatus.printed;
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
