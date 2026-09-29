import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aksy/core/data/app_store.dart';
import 'package:aksy/features/pos/models/product.dart';
import 'package:aksy/features/pos/providers/cart_provider.dart';
import 'package:aksy/features/printer/models/bluetooth_printer_device.dart';
import 'package:aksy/features/printer/models/printer_settings.dart';
import 'package:aksy/features/printer/services/esc_pos_receipt.dart';
import 'package:aksy/features/printer/services/thermal_printer_service.dart';

Product _product() => Product(
  id: 'p1',
  name: 'Teh Pucuk',
  price: 5000,
  category: 'Minuman',
  icon: ProductIcons.fallback,
  stock: 100,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('auto print gating', () {
    test('autoPrint alone is not enough, the device must be configured', () {
      const settings = PrinterSettings(autoPrint: true);
      expect(settings.autoPrint, isTrue);
      expect(settings.isConfigured, isFalse);
    });

    test('autoPrint plus a device address makes the store print-ready', () {
      const settings = PrinterSettings(
        autoPrint: true,
        deviceAddress: '00:11:22:33:44:55',
        deviceName: 'Rongta RP58',
      );
      expect(settings.autoPrint, isTrue);
      expect(settings.isConfigured, isTrue);
    });

    test('copyWith keeps autoPrint while filling in the device', () {
      const initial = PrinterSettings(autoPrint: true);
      final selected = initial.copyWith(
        deviceAddress: '00:11:22:33:44:55',
        deviceName: 'Rongta RP58',
      );
      expect(selected.autoPrint, isTrue);
      expect(selected.isConfigured, isTrue);
    });
  });

  group('printer selection persists through AppStore', () {
    test('selecting a device then survives a store reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore.fromPrefs(prefs);

      const device = BluetoothPrinterDevice(
        name: 'Rongta RP58',
        address: '00:11:22:33:44:55',
      );
      store.updatePrinterSettings(
        store.printer.copyWith(
          deviceAddress: device.address,
          deviceName: device.name,
        ),
      );

      final reloaded = AppStore.fromPrefs(prefs);
      expect(reloaded.printer.isConfigured, isTrue);
      expect(reloaded.printer.deviceAddress, '00:11:22:33:44:55');
      expect(reloaded.printer.deviceName, 'Rongta RP58');
    });

    test('autoPrint survives a store reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore.fromPrefs(prefs);
      store
        ..updatePrinterSettings(
          store.printer.copyWith(
            deviceAddress: '00:11:22:33:44:55',
            deviceName: 'Rongta RP58',
          ),
        )
        ..updatePrinterSettings(store.printer.copyWith(autoPrint: true));

      final reloaded = AppStore.fromPrefs(prefs);
      expect(reloaded.printer.isConfigured, isTrue);
      expect(reloaded.printer.autoPrint, isTrue);
    });
  });

  group('receipt payload for a configured printer', () {
    test('is built from the same order the transaction saved', () {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore(products: [_product()]);
      final cart = CartProvider()..addItem(_product());
      final order = cart.submitOrder(10000, store);

      final bytes = buildReceiptEscPos(
        order: order,
        store: store,
        wide: store.printer.wide,
        cut: store.printer.cut,
      );

      expect(store.orders, hasLength(1));
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes), contains(order.id));
    });

    test('disabling cut removes the cut command from the payload', () {
      final store = AppStore(products: [_product()]);
      final cart = CartProvider()..addItem(_product());
      final order = cart.submitOrder(10000, store);

      final withCut = buildReceiptEscPos(
        order: order,
        store: store,
        wide: false,
        cut: true,
      );
      final withoutCut = buildReceiptEscPos(
        order: order,
        store: store,
        wide: false,
        cut: false,
      );

      expect(
        withCut.sublist(withCut.length - 3),
        [0x1D, 0x56, 0x00],
      );
      expect(
        withoutCut.sublist(withoutCut.length - 3),
        isNot([0x1D, 0x56, 0x00]),
      );
      expect(withoutCut.length, lessThan(withCut.length));
    });
  });

  group('BluetoothPrinterDevice', () {
    test('compares by name and address', () {
      const a = BluetoothPrinterDevice(name: 'Rongta', address: 'AA:BB');
      const b = BluetoothPrinterDevice(name: 'Rongta', address: 'AA:BB');
      const c = BluetoothPrinterDevice(name: 'Rongta', address: 'CC:DD');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('ThermalPrinterService platform gating', () {
    test('reports unsupported off Android', () async {
      final service = ThermalPrinterService();
      if (service.isSupported) return;
      await expectLater(
        service.listPairedDevices(),
        throwsA(isA<PrinterException>()),
      );
    });
  });
}
