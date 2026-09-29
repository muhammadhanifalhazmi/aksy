import 'package:flutter/material.dart';

import '../../../core/data/app_store.dart';
import '../../../core/widgets/app_navigation_drawer.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../models/bluetooth_printer_device.dart';
import '../models/printer_settings.dart';
import '../services/thermal_printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
    this.service,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ThermalPrinterService? service;

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late final ThermalPrinterService _service;
  List<BluetoothPrinterDevice> _devices = const [];
  bool _initialized = false;
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _service = widget.service ?? ThermalPrinterService();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      if (!_service.isSupported) {
        _setStatus('Printer Bluetooth hanya tersedia di Android', isError: true);
        return;
      }
      if (!await _service.hasPermissions()) {
        final granted = await _service.requestPermissions();
        if (!granted) {
          _setStatus('Izin Bluetooth diperlukan untuk mencetak', isError: true);
          return;
        }
      }
      if (!await _service.isBluetoothAvailable()) {
        _setStatus('Bluetooth mati, nyalakan dulu di pengaturan sistem', isError: true);
        return;
      }
      final devices = await _service.listPairedDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _statusMessage = devices.isEmpty
            ? 'Belum ada printer yang dipairingkan'
            : '${devices.length} printer ditemukan';
        _statusIsError = devices.isEmpty;
      });
    } on PrinterException catch (error) {
      _setStatus(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setStatus(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _select(BluetoothPrinterDevice device) async {
    final store = AppScope.of(context);
    final connected = await _run(
      () => _service.connect(
        store.printer.copyWith(
          deviceAddress: device.address,
          deviceName: device.name,
        ),
      ),
      successMessage: 'Printer ${device.name} dipilih',
    );
    if (!connected || !mounted) return;
    store.updatePrinterSettings(
      store.printer.copyWith(
        deviceAddress: device.address,
        deviceName: device.name,
      ),
    );
  }

  Future<void> _testPrint() async {
    final store = AppScope.of(context);
    final settings = store.printer;
    if (!settings.isConfigured) {
      _setStatus('Pilih printer terlebih dahulu', isError: true);
      return;
    }
    await _run(
      () => _service.printTest(settings),
      successMessage: 'Struk uji dikirim ke printer',
    );
  }

  Future<bool> _run(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_busy) return false;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await action();
      _setStatus(successMessage, isError: false);
      return true;
    } on PrinterException catch (error) {
      _setStatus(error.message, isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _update(PrinterSettings Function(PrinterSettings) change) {
    final store = AppScope.of(context);
    store.updatePrinterSettings(change(store.printer));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final printer = AppScope.of(context).printer;

    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: widget.selectedDestination,
        onDestinationSelected: widget.onDestinationSelected,
      ),
      appBar: AppBar(title: const Text('Printer Termal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Perangkat'),
          const SizedBox(height: 4),
          Text(
            'Printer harus sudah dipairingkan di pengaturan Bluetooth ponsel '
            'sebelum bisa dipilih di sini.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_statusMessage != null) ...[
                  Row(
                    children: [
                      Icon(
                        _statusIsError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 18,
                        color: _statusIsError
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _load,
                          icon: const Icon(Icons.bluetooth_searching),
                          label: const Text('Cari Printer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : _service.openBluetoothSettings,
                          icon: const Icon(Icons.settings_bluetooth),
                          label: const Text('Pengaturan BT'),
                        ),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Printer Terpilih'),
          const SizedBox(height: 12),
          if (_devices.isEmpty && !_busy)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Icons.print_outlined,
                  title: 'Belum ada printer',
                  subtitle:
                      'Pairing printer lewat pengaturan Bluetooth ponsel, '
                      'lalu tekan Cari Printer.',
                ),
              ),
            )
          else
            for (final device in _devices)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: RadioListTile<String>(
                  value: device.address,
                  groupValue: printer.deviceAddress,
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          final match = _devices.firstWhere(
                            (d) => d.address == value,
                          );
                          _select(match);
                        },
                  title: Text(device.name),
                  subtitle: Text(device.address),
                  secondary: IconButton(
                    tooltip: 'Cetak uji',
                    onPressed: _busy ? null : _testPrint,
                    icon: const Icon(Icons.print_outlined),
                  ),
                ),
              ),
          const SizedBox(height: 12),
          const SectionHeader(title: 'Opsi Cetak'),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: printer.autoPrint,
                  onChanged: (value) => _update(
                    (current) => current.copyWith(autoPrint: value),
                  ),
                  title: const Text('Cetak otomatis setelah pembayaran'),
                  subtitle: const Text(
                    'Struk langsung keluar tanpa perlu menekan tombol cetak',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: printer.cut,
                  onChanged: (value) => _update(
                    (current) => current.copyWith(cut: value),
                  ),
                  title: const Text('Potong kertas otomatis'),
                  subtitle: const Text(
                    'Matikan bila printer tidak memiliki pemotong kertas (cutter)',
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Lebar kertas', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: false, label: Text('58mm')),
                          ButtonSegment(value: true, label: Text('80mm')),
                        ],
                        selected: {printer.wide},
                        onSelectionChanged: (selection) => _update(
                          (current) =>
                              current.copyWith(wide: selection.first),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Jumlah salinan', style: theme.textTheme.titleSmall),
                          ),
                          IconButton.filledTonal(
                            onPressed: printer.copies <= 1
                                ? null
                                : () => _update(
                                    (c) => c.copyWith(copies: c.copies - 1),
                                  ),
                            icon: const Icon(Icons.remove),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '${printer.copies}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: printer.copies >= 5
                                ? null
                                : () => _update(
                                    (c) => c.copyWith(copies: c.copies + 1),
                                  ),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
