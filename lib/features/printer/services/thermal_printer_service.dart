import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/data/app_store.dart';
import '../../pos/models/order.dart';
import '../models/bluetooth_printer_device.dart';
import '../models/printer_settings.dart';
import 'esc_pos_receipt.dart';

class ThermalPrinterService {
  ThermalPrinterService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.example.aksy/printer';

  final MethodChannel _channel;

  String? _connectedAddress;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _ensureSupported() async {
    if (!isSupported) {
      throw const PrinterException(
        'Printer Bluetooth hanya tersedia di aplikasi Android',
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (error) {
      throw PrinterException(_friendlyMessage(error));
    } on MissingPluginException {
      throw const PrinterException(
        'Modul printer Bluetooth belum tersedia, rebuild aplikasi',
      );
    }
  }

  String _friendlyMessage(PlatformException error) {
    return switch (error.code) {
      'permission_denied' => 'Izin Bluetooth belum diberikan',
      'not_paired' => 'Printer belum dipairingkan dengan perangkat ini',
      'not_connected' => 'Printer belum terhubung',
      'connect_failed' => 'Gagal terhubung ke printer, pastikan printer menyala',
      'print_failed' => 'Gagal mengirim data ke printer',
      'invalid_address' => 'Printer yang dipilih tidak valid',
      _ => 'Terjadi kesalahan pada printer',
    };
  }

  Future<bool> hasPermissions() => _invokeBool('hasPermissions');

  Future<bool> requestPermissions() => _invokeBool('requestPermissions');

  Future<bool> isBluetoothAvailable() => _invokeBool('isBluetoothAvailable');

  Future<bool> _invokeBool(String method) async {
    await _ensureSupported();
    final result = await _guard<bool?>(() => _channel.invokeMethod<bool>(method));
    return result ?? false;
  }

  Future<void> openBluetoothSettings() async {
    await _ensureSupported();
    await _guard(() => _channel.invokeMethod<void>('openBluetoothSettings'));
  }

  Future<List<BluetoothPrinterDevice>> listPairedDevices() async {
    await _ensureSupported();
    final raw = await _guard(
      () => _channel.invokeListMethod<Map<Object?, Object?>>(
        'listPairedDevices',
      ),
    );
    return (raw ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(
          (entry) => BluetoothPrinterDevice(
            name: entry['name'] as String? ?? 'Printer',
            address: entry['address'] as String? ?? '',
          ),
        )
        .where((device) => device.address.isNotEmpty)
        .toList();
  }

  Future<void> connect(PrinterSettings settings) async {
    if (!settings.isConfigured) {
      throw const PrinterException('Belum ada printer yang dipilih');
    }
    await _ensureSupported();
    await _guard(
      () => _channel.invokeMethod<void>('connect', {
        'address': settings.deviceAddress,
      }),
    );
    _connectedAddress = settings.deviceAddress;
  }

  Future<bool> isConnected() => _invokeBool('isConnected');

  Future<void> disconnect() async {
    if (!isSupported) return;
    await _guard(() => _channel.invokeMethod<void>('disconnect'));
    _connectedAddress = null;
  }

  Future<void> printBytes(Uint8List bytes) async {
    await _ensureSupported();
    await _guard(() => _channel.invokeMethod<int>('print', {'bytes': bytes}));
  }

  Future<void> printReceipt({
    required PrinterSettings settings,
    required AppStore store,
    required Order order,
  }) {
    return _print(
      settings,
      buildReceiptEscPos(order: order, store: store, wide: settings.wide),
    );
  }

  Future<void> printTest(PrinterSettings settings) {
    return _print(settings, buildTestEscPos(wide: settings.wide));
  }

  Future<void> _print(PrinterSettings settings, Uint8List bytes) async {
    final alreadyConnected =
        _connectedAddress == settings.deviceAddress && await isConnected();
    if (!alreadyConnected) {
      await connect(settings);
    }
    for (var copy = 0; copy < settings.copies; copy++) {
      await printBytes(bytes);
    }
  }
}
