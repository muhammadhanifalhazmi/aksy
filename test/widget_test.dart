import 'dart:convert';

import 'package:aksy/app_shell_screen.dart';
import 'package:aksy/core/data/app_store.dart';
import 'package:aksy/core/data/store_settings.dart';
import 'package:aksy/core/utils/currency_formatter.dart';
import 'package:aksy/core/widgets/app_navigation_drawer.dart';
import 'package:aksy/features/cash_flow/models/cash_entry.dart';
import 'package:aksy/features/debt/models/debt.dart';
import 'package:aksy/features/pos/models/product.dart';
import 'package:aksy/features/pos/providers/cart_provider.dart';
import 'package:aksy/features/printer/models/printer_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats Indonesian Rupiah', () {
      expect(CurrencyFormatter.formatIDR(18000), 'Rp 18.000');
      expect(CurrencyFormatter.formatIDR(5000), 'Rp 5.000');
      expect(CurrencyFormatter.formatIDR(1000000), 'Rp 1.000.000');
    });
  });

  group('CartProvider', () {
    test('adds items and merges quantities', () {
      final cart = CartProvider();
      final product = _product(
        id: 'p1',
        name: 'Kopi Susu Aren',
        price: 18000,
        category: 'Minuman',
      );
      cart.addItem(product);
      cart.addItem(product);
      expect(cart.itemCount, 2);
      expect(cart.subtotal, 36000);
      expect(cart.items.single.quantity, 2);
    });

    test('decrement removes item when quantity reaches zero', () {
      final cart = CartProvider();
      final product = _product(
        id: 'p1',
        name: 'Es Teh',
        price: 5000,
        category: 'Minuman',
      );
      cart.addItem(product);
      cart.decrement('p1');
      expect(cart.isEmpty, isTrue);
    });

    test('does not exceed available stock in addItem', () {
      final cart = CartProvider();
      final product = _product(
        id: 'p1',
        name: 'Air Mineral',
        price: 3000,
        category: 'Minuman',
      );
      cart.addItem(product, availableStock: 2);
      cart.addItem(product, availableStock: 2);
      cart.addItem(product, availableStock: 2);
      expect(cart.itemCount, 2);
    });

    test('submitOrder records into store, clears cart, computes change', () {
      final cart = CartProvider();
      final store = AppStore();
      final product = _product(
        id: 'p1',
        name: 'Roti Bakar',
        price: 12000,
        category: 'Snack',
      );
      cart.addItem(product);
      final order = cart.submitOrder(20000, store);
      expect(order.total, 12000);
      expect(order.change, 8000);
      expect(cart.isEmpty, isTrue);
      expect(store.orders, hasLength(1));
    });
  });

  group('App navigation', () {
    testWidgets('drawer is available on every primary page', (tester) async {
      final store = AppStore();
      final cart = CartProvider();
      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CartScope(
            notifier: cart,
            child: const MaterialApp(home: AppShellScreen()),
          ),
        ),
      );

      Future<void> selectDestination(String label) async {
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(NavigationDrawerDestination, label),
        );
        await tester.pumpAndSettle();
      }

      expect(find.byTooltip('Inventori'), findsOneWidget);
      await selectDestination('Inventori');
      expect(find.text('Inventori'), findsOneWidget);
      await selectDestination('Kas Masuk / Keluar');
      expect(find.text('Kas Masuk / Keluar'), findsOneWidget);
      await selectDestination('Hutang & Piutang');
      expect(find.text('Hutang & Piutang'), findsOneWidget);
      await selectDestination('Shift Kasir');
      expect(find.text('Shift Kasir'), findsOneWidget);
      await selectDestination('Printer Termal');
      expect(find.text('Printer Termal'), findsOneWidget);
      await selectDestination('Pengaturan');
      expect(find.text('Pengaturan'), findsOneWidget);
      await selectDestination('Laporan');
      expect(find.text('Laporan'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      final drawers = tester.widgetList<NavigationDrawer>(
        find.byType(NavigationDrawer, skipOffstage: false),
      );
      expect(drawers, isNotEmpty);
      expect(
        drawers.any(
          (drawer) => drawer.selectedIndex == AppDestination.reports.index,
        ),
        isTrue,
      );
    });
  });

  group('tablet layout', () {
    // 800 x 1280 ~= tablet 7" portrait (TabletSize.iPadPortrait). Memastikan
    // tidak ada RenderFlex overflow saat aplikasi dibuka di tablet.
    testWidgets('opens every main screen on a tablet without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = AppStore(products: [
        Product(
          id: 'p1',
          name: 'Es Teh Manis',
          price: 5000,
          category: 'Minuman',
          icon: Icons.local_drink,
          stock: 20,
          costPrice: 2500,
        ),
      ]);

      for (final label in const [
        'POS',
        'Inventori',
        'Kas Masuk / Keluar',
        'Hutang & Piutang',
        'Shift Kasir',
        'Laporan',
        'Printer Termal',
        'Pengaturan',
        'Panduan',
      ]) {
        await _pumpApp(tester, store: store);
        await tester.pumpAndSettle();
        await _openDestination(tester, label);

        expect(
          tester.takeException(),
          isNull,
          reason: 'halaman "$label" meluber di layar tablet',
        );
        expect(find.byType(AppShellScreen), findsOneWidget);
      }
    });
  });

  group('DebtScreen', () {
    testWidgets('a debt record can be edited from the card menu', (
      tester,
    ) async {
      final store = AppStore()
        ..addDebt(
          Debt(
            id: 'D1',
            type: DebtType.receivable,
            partyName: 'Budi',
            amount: 50000,
            createdAt: DateTime.now(),
          ),
        );
      await _pumpApp(tester, store: store);
      await _openDestination(tester, 'Hutang & Piutang');

      await tester.tap(find.byTooltip('Ubah catatan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ubah').last);
      await tester.pumpAndSettle();

      expect(find.text('Ubah Catatan'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nominal (Rp)'),
        '75000',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(store.debts.single.amount, 75000);
      expect(store.debts.single.partyName, 'Budi');
      expect(find.text('Rp 75.000'), findsWidgets);
    });

    testWidgets('deleting a debt asks for confirmation first', (tester) async {
      final store = AppStore()
        ..addDebt(
          Debt(
            id: 'D1',
            type: DebtType.receivable,
            partyName: 'Budi',
            amount: 50000,
            createdAt: DateTime.now(),
          ),
        );
      await _pumpApp(tester, store: store);
      await _openDestination(tester, 'Hutang & Piutang');

      await tester.tap(find.byTooltip('Ubah catatan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();

      expect(find.text('Hapus catatan?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();
      expect(store.debts, hasLength(1));

      await tester.tap(find.byTooltip('Ubah catatan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();

      expect(store.debts, isEmpty);
      expect(find.text('Belum ada catatan'), findsOneWidget);
    });
  });

  group('CashFlowScreen', () {
    testWidgets('a manual cash entry can be edited and deleted', (
      tester,
    ) async {
      final store = AppStore()
        ..addCashEntry(
          CashEntry(
            id: 'CF1',
            type: CashFlowType.cashIn,
            amount: 50000,
            category: 'Modal Masuk',
            note: 'modal awal',
            createdAt: DateTime.now(),
          ),
        );
      await _pumpApp(tester, store: store);
      await _openDestination(tester, 'Kas Masuk / Keluar');

      await tester.tap(find.byTooltip('Ubah catatan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ubah').last);
      await tester.pumpAndSettle();

      expect(find.text('Ubah Catatan Kas'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nominal (Rp)'),
        '45000',
      );
      await tester.tap(find.text('Simpan Catatan'));
      await tester.pumpAndSettle();

      expect(store.cashEntries.single.amount, 45000);
      expect(find.text('+Rp 45.000'), findsOneWidget);

      await tester.tap(find.byTooltip('Ubah catatan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();

      expect(store.cashEntries, isEmpty);
      expect(find.text('Belum ada catatan'), findsOneWidget);
    });

    testWidgets('automatic sale entries are locked with an explanation', (
      tester,
    ) async {
      final store = AppStore();
      final product = _product(
        id: 'p1',
        name: 'Es Teh',
        price: 5000,
        category: 'Minuman',
        stock: 20,
      );
      store.addProduct(product);
      (CartProvider()..addItem(product)).submitOrder(10000, store);
      await _pumpApp(tester, store: store);
      await _openDestination(tester, 'Kas Masuk / Keluar');

      expect(find.byTooltip('Ubah catatan'), findsNothing);
      await tester.tap(find.byTooltip('Catatan otomatis'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('dibuat otomatis dari penjualan'),
        findsOneWidget,
      );
      expect(store.cashEntries, hasLength(1));
    });
  });

  group('InventoryScreen', () {
    testWidgets('deletes a product after confirmation', (tester) async {
      final product = _product(
        id: 'p1',
        name: 'Kopi Susu',
        price: 18000,
        category: 'Minuman',
      );
      final store = AppStore(products: [product]);
      final cart = CartProvider()..addItem(product);

      await _pumpApp(tester, store: store, cart: cart);

      await tester.tap(find.byTooltip('Inventori'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hapus produk'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();
      expect(store.products, [product]);

      await tester.tap(find.byTooltip('Hapus produk'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();

      expect(store.products, isEmpty);
      expect(cart.isEmpty, isTrue);
      expect(find.text(product.name), findsNothing);
    });
  });

  group('Payment dialog', () {
    testWidgets('paying with a discount closes cleanly and saves the order', (
      tester,
    ) async {
      final product = _product(
        id: 'p1',
        name: 'Kopi Susu',
        price: 18000,
        category: 'Minuman',
      );
      final store = AppStore(products: [product]);
      final cart = CartProvider()..addItem(product);

      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CartScope(
            notifier: cart,
            child: const MaterialApp(home: AppShellScreen()),
          ),
        ),
      );

      await _openPaymentDialog(tester);


      await tester.enterText(
        find.widgetWithText(TextField, 'Diskon (Rp)'),
        '3000',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ActionChip, 'Uang Pas'));
      await tester.pumpAndSettle();

      await tester.tap(_dialogBayar);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(store.orders, hasLength(1));
      expect(store.orders.single.discount, 3000);
      expect(store.orders.single.total, 15000);
      expect(cart.isEmpty, isTrue);
    });

    testWidgets('tapping Bayar twice records a single order', (tester) async {
      final product = _product(
        id: 'p1',
        name: 'Kopi Susu',
        price: 18000,
        category: 'Minuman',
      );
      final store = AppStore(products: [product]);
      final cart = CartProvider()..addItem(product);

      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CartScope(
            notifier: cart,
            child: const MaterialApp(home: AppShellScreen()),
          ),
        ),
      );

      await _openPaymentDialog(tester);

      await tester.tap(_dialogBayar);
      await tester.tap(_dialogBayar, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(store.orders, hasLength(1));
    });

    testWidgets('a discount above the subtotal is capped, never negative', (
      tester,
    ) async {
      final product = _product(
        id: 'p1',
        name: 'Kopi Susu',
        price: 18000,
        category: 'Minuman',
      );
      final store = AppStore(products: [product]);
      final cart = CartProvider()..addItem(product);

      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CartScope(
            notifier: cart,
            child: const MaterialApp(home: AppShellScreen()),
          ),
        ),
      );

      await _openPaymentDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Diskon (Rp)'),
        '999999',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Total tagihan Rp -'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.textContaining('Kurang'),
        ),
        findsNothing,
      );

      await tester.tap(_dialogBayar);
      await tester.pumpAndSettle();

      expect(store.orders.single.discount, 18000);
      expect(store.orders.single.total, 0);
      expect(store.orders.single.change, 18000);
      expect(store.orders.single.paidAmount, 18000);
    });

    testWidgets('paying is blocked when a cart product was deleted', (
      tester,
    ) async {
      final product = _product(
        id: 'p1',
        name: 'Kopi Susu',
        price: 18000,
        category: 'Minuman',
      );
      final store = AppStore(products: [product]);
      final cart = CartProvider()..addItem(product);

      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CartScope(
            notifier: cart,
            child: const MaterialApp(home: AppShellScreen()),
          ),
        ),
      );

      await _openPaymentDialog(tester);
      store.removeProduct('p1');
      await tester.tap(_dialogBayar);
      await tester.pumpAndSettle();

      expect(store.orders, isEmpty);
      expect(cart.isEmpty, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('POS cart sheet', () {
    testWidgets('quantity stepper updates the cart shown in the sheet', (
      tester,
    ) async {
      final product = _product(
        id: 'p1',
        name: 'Kopi Susu',
        price: 18000,
        category: 'Minuman',
      );
      final store = AppStore(products: [product]);
      final cart = CartProvider()..addItem(product);

      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CartScope(
            notifier: cart,
            child: const MaterialApp(home: AppShellScreen()),
          ),
        ),
      );

      final sheet = find.byType(BottomSheet);
      Finder inSheet(String text) =>
          find.descendant(of: sheet, matching: find.text(text));

      await tester.tap(find.byTooltip('Keranjang'));
      await tester.pumpAndSettle();
      expect(inSheet('1'), findsOneWidget);
      expect(inSheet('1 item'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(cart.quantityOf('p1'), 2);
      expect(inSheet('2'), findsOneWidget);
      expect(inSheet('2 item'), findsOneWidget);
      expect(inSheet('Rp 36.000'), findsWidgets);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(cart.quantityOf('p1'), 1);
      expect(inSheet('1'), findsOneWidget);
      expect(inSheet('1 item'), findsOneWidget);
      expect(inSheet('Rp 18.000'), findsWidgets);
    });
  });

  group('Tiered pricing', () {
    test('unitPriceFor falls back to retail without wholesale tier', () {
      final product = _product(
        id: 'p1',
        name: 'Es Teh',
        price: 5000,
        category: 'Minuman',
      );
      expect(product.unitPriceFor(100), 5000);
    });

    test('wholesale price applies once minimum quantity reached', () {
      final product = const Product(
        id: 'p9',
        name: 'Air Mineral',
        price: 3000,
        category: 'Minuman',
        icon: Icons.water_drop,
        wholesalePrice: 2700,
        minWholesaleQty: 12,
        stock: 50,
      );
      expect(product.unitPriceFor(11), 3000);
      expect(product.unitPriceFor(12), 2700);
      expect(product.unitPriceFor(24), 2700);
    });

    test('cart subtotal switches to wholesale dynamically', () {
      final cart = CartProvider();
      final product = const Product(
        id: 'p9',
        name: 'Air Mineral',
        price: 3000,
        category: 'Minuman',
        icon: Icons.water_drop,
        wholesalePrice: 2700,
        minWholesaleQty: 12,
        stock: 50,
      );
      for (var i = 0; i < 11; i++) {
        cart.addItem(product, availableStock: 50);
      }
      expect(cart.subtotal, 11 * 3000);
      cart.addItem(product, availableStock: 50);
      expect(cart.subtotal, 12 * 2700);
    });
  });

  group('AppStore', () {
    test('recordOrder deducts stock and adds sales cash entry', () {
      final product = _product(
        id: 'p1',
        name: 'Air Mineral',
        price: 3000,
        category: 'Minuman',
        stock: 10,
      );
      final store = AppStore(products: [product]);
      final cart = CartProvider();
      cart.addItem(product);
      cart.addItem(product, availableStock: 10);

      final order = cart.submitOrder(10000, store);

      expect(order.items.fold(0, (s, i) => s + i.quantity), 2);
      expect(store.stockOf('p1'), 8);
      expect(store.cashInOn(DateTime.now()), 6000);
    });

    test('removeProduct removes only the selected product', () {
      final first = _product(
        id: 'p1',
        name: 'Air Mineral',
        price: 3000,
        category: 'Minuman',
      );
      final second = _product(
        id: 'p2',
        name: 'Es Teh',
        price: 5000,
        category: 'Minuman',
      );
      final store = AppStore(products: [first, second]);

      store.removeProduct('p1');
      store.removeProduct('missing');

      expect(store.products, [second]);
    });

    test('productByBarcode resolves matching barcode', () {
      final product = const Product(
        id: 'p1',
        name: 'Air Mineral',
        price: 3000,
        category: 'Minuman',
        icon: Icons.water_drop,
        stock: 50,
        barcode: '8991001234567',
      );
      final store = AppStore(products: [product]);
      expect(store.productByBarcode('8991001234567'), same(product));
      expect(store.productByBarcode(' 8991001234567 '), same(product));
      expect(store.productByBarcode('000'), isNull);
      expect(store.productByBarcode(''), isNull);
    });

    test('productByBarcode ignores letter case', () {
      final product = const Product(
        id: 'p2',
        name: 'Kopi Bubuk',
        price: 45000,
        category: 'Minuman',
        icon: Icons.coffee,
        stock: 20,
        barcode: 'SKU-ABC12',
      );
      final store = AppStore(products: [product]);
      expect(store.productByBarcode('sku-abc12'), same(product));
      expect(store.productByBarcode('SKU-ABC12'), same(product));
    });

    test(
      'recordDebtPayment supports partial payment and updates cash flow',
      () {
        final store = AppStore();
        final debt = Debt(
          id: 'd1',
          type: DebtType.receivable,
          partyName: 'Budi',
          amount: 100000,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        );
        store.addDebt(debt);
        expect(store.debts.single.remaining, 100000);

        store.recordDebtPayment('d1', 40000);
        expect(store.debts.single.remaining, 60000);
        expect(store.debts.single.isPaid, isFalse);
        expect(store.cashInOn(DateTime.now()), 40000);

        store.recordDebtPayment('d1', 60000);
        expect(store.debts.single.isPaid, isTrue);
        expect(store.cashInOn(DateTime.now()), 100000);
      },
    );

    test('updateDebt changes the record but keeps payments intact', () {
      final store = AppStore();
      final debt = Debt(
        id: 'd1',
        type: DebtType.receivable,
        partyName: 'Budi',
        amount: 100000,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      store.addDebt(debt);
      store.recordDebtPayment('d1', 30000);

      final updated = store.debts.single.copyWith(
        partyName: 'Budi Santoso',
        amount: 120000,
        note: 'follow up minggu depan',
      );
      expect(store.updateDebt(updated), isTrue);

      final saved = store.debts.single;
      expect(saved.partyName, 'Budi Santoso');
      expect(saved.amount, 120000);
      expect(saved.remaining, 90000);
      expect(saved.paidAmount, 30000);
      expect(saved.payments, hasLength(1));
      expect(saved.note, 'follow up minggu depan');
    });

    test('updateDebt refuses an amount below what was already paid', () {
      final store = AppStore();
      store.addDebt(
        Debt(
          id: 'd1',
          type: DebtType.receivable,
          partyName: 'Budi',
          amount: 100000,
          createdAt: DateTime.now(),
        ),
      );
      store.recordDebtPayment('d1', 70000);

      final broken = store.debts.single.copyWith(amount: 50000);
      expect(store.updateDebt(broken), isFalse);
      expect(store.debts.single.amount, 100000);
    });

    test('removeDebt also drops the cash entries it created', () {
      final store = AppStore();
      store.addDebt(
        Debt(
          id: 'd1',
          type: DebtType.receivable,
          partyName: 'Budi',
          amount: 100000,
          createdAt: DateTime.now(),
        ),
      );
      store.recordDebtPayment('d1', 40000);
      store.addCashEntry(
        CashEntry(
          id: 'CFmanual',
          type: CashFlowType.cashIn,
          amount: 5000,
          category: 'Lainnya',
          createdAt: DateTime.now(),
        ),
      );
      expect(store.cashEntries, hasLength(2));

      expect(store.removeDebt('d1'), isTrue);

      expect(store.debts, isEmpty);
      expect(store.cashEntries.single.id, 'CFmanual');
      expect(store.removeDebt('d1'), isFalse);
    });

    test('automatic cash entries cannot be edited or deleted', () {
      final store = AppStore();
      final product = _product(
        id: 'p1',
        name: 'Es Teh',
        price: 5000,
        category: 'Minuman',
        stock: 10,
      );
      store.addProduct(product);
      (CartProvider()..addItem(product)).submitOrder(10000, store);
      store.addDebt(
        Debt(
          id: 'd1',
          type: DebtType.receivable,
          partyName: 'Budi',
          amount: 50000,
          createdAt: DateTime.now(),
        ),
      );
      store.recordDebtPayment('d1', 20000);

      final sale = store.cashEntries.firstWhere((e) => e.category == 'Penjualan');
      final payment =
          store.cashEntries.firstWhere((e) => e.category == 'Pembayaran Piutang');
      expect(sale.isEditable, isFalse);
      expect(payment.isEditable, isFalse);
      expect(payment.debtId, 'd1');

      expect(store.updateCashEntry(sale.copyWith(amount: 1)), isFalse);
      expect(store.removeCashEntry(payment.id), isFalse);
      expect(store.cashEntries, hasLength(2));
      expect(store.cashInOn(DateTime.now()), 25000);
    });

    test('manual cash entries can be edited and deleted', () {
      final store = AppStore();
      final entry = CashEntry(
        id: 'CF1',
        type: CashFlowType.cashOut,
        amount: 50000,
        category: 'Belanja Stok',
        note: 'beli teh',
        createdAt: DateTime.now(),
      );
      store.addCashEntry(entry);
      expect(entry.isEditable, isTrue);

      expect(
        store.updateCashEntry(entry.copyWith(amount: 45000, note: 'teh + gula')),
        isTrue,
      );
      expect(store.cashEntries.single.amount, 45000);
      expect(store.cashEntries.single.note, 'teh + gula');

      expect(store.removeCashEntry('CF1'), isTrue);
      expect(store.cashEntries, isEmpty);
      expect(store.removeCashEntry('CF1'), isFalse);
    });

    test('auto cash entries from legacy json without source stay editable', () {
      final legacy = CashEntry.fromJson({
        'id': 'CF1',
        'type': 'cashOut',
        'amount': 10000,
        'category': 'Belanja Stok',
        'createdAt': DateTime.now().toIso8601String(),
        'note': null,
      });
      expect(legacy.isEditable, isTrue);

      final sale = CashEntry.fromJson({
        'id': 'CF2',
        'type': 'cashIn',
        'amount': 10000,
        'category': 'Penjualan',
        'createdAt': DateTime.now().toIso8601String(),
        'note': null,
      });
      expect(sale.isEditable, isFalse);
      expect(sale.source, CashEntrySource.sale);
    });

    test('nextId never collides inside the same millisecond', () {
      final store = AppStore();
      for (var i = 0; i < 50; i++) {
        store.addCashEntry(
          CashEntry(
            id: store.nextId('CF'),
            type: CashFlowType.cashIn,
            amount: 1000,
            category: 'Lainnya',
            createdAt: DateTime.now(),
          ),
        );
      }
      expect(store.cashEntries, hasLength(50));
      expect(store.cashEntries.map((e) => e.id).toSet(), hasLength(50));
    });

    test('open/close shift computes expected cash and discrepancy', () {
      final product = _product(
        id: 'p1',
        name: 'Es Teh',
        price: 5000,
        category: 'Minuman',
        stock: 20,
      );
      final store = AppStore(products: [product]);
      store.openShift(100000);

      final cart = CartProvider();
      cart.addItem(product);
      cart.submitOrder(5000, store);

      final closed = store.closeShift(108000)!;
      expect(closed.expectedCash, 105000);
      expect(closed.difference, 3000);
      expect(store.activeShift, isNull);
    });
  });

  group('AppStore persistence', () {
    test('round-trips all data through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var store = AppStore.fromPrefs(prefs);

      final product = _product(
        id: 'p1',
        name: 'Air Mineral',
        price: 3000,
        category: 'Minuman',
        stock: 10,
      );
      store.addProduct(product);
      store.openShift(50000);

      final cart = CartProvider();
      cart.addItem(product);
      cart.submitOrder(10000, store);

      store.addDebt(
        Debt(
          id: 'd1',
          type: DebtType.receivable,
          partyName: 'Budi',
          amount: 50000,
          createdAt: DateTime.now(),
        ),
      );

      store = AppStore.fromPrefs(prefs);
      expect(store.products.single.id, 'p1');
      expect(store.stockOf('p1'), 9);
      expect(store.orders.single.items.single.quantity, 1);
      expect(store.cashEntries, hasLength(1));
      expect(store.debts.single.partyName, 'Budi');
      expect(store.activeShift, isNotNull);
    });

    test('removeProduct persists the deletion', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final deleted = _product(
        id: 'p1',
        name: 'Kopi',
        price: 15000,
        category: 'Minuman',
      );
      final retained = _product(
        id: 'p2',
        name: 'Teh',
        price: 5000,
        category: 'Minuman',
      );
      final store = AppStore(prefs: prefs)
        ..addProduct(deleted)
        ..addProduct(retained);
      await Future<void>.delayed(Duration.zero);

      store.removeProduct(deleted.id);
      await Future<void>.delayed(Duration.zero);

      final restored = AppStore.fromPrefs(prefs);
      expect(restored.products, hasLength(1));
      expect(restored.products.single.id, retained.id);
    });

    test('store settings persist through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      AppStore.fromPrefs(prefs).updateStoreSettings(
        const StoreSettings(
          name: 'Toko Bahagia',
          address: 'Jl. Sudirman No. 1',
          phone: '08123456789',
          footer: 'Terima kasih sudah belanja',
        ),
      );

      final restored = AppStore.fromPrefs(prefs);
      expect(restored.settings.name, 'Toko Bahagia');
      expect(restored.settings.address, 'Jl. Sudirman No. 1');
      expect(restored.settings.phone, '08123456789');
      expect(restored.settings.footer, 'Terima kasih sudah belanja');
    });

    test('store settings default to Aplikasi Kasir Easy', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore.fromPrefs(prefs);
      expect(store.settings.name, 'Aplikasi Kasir Easy');
      expect(store.settings.address, '');
      expect(store.settings.phone, '');
    });

    test('printer settings persist through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      AppStore.fromPrefs(prefs).updatePrinterSettings(
        const PrinterSettings(
          deviceAddress: '00:11:22:33:44:55',
          deviceName: 'Rongta RP58',
          wide: true,
          autoPrint: true,
          copies: 2,
        ),
      );

      final restored = AppStore.fromPrefs(prefs);
      expect(restored.printer.deviceAddress, '00:11:22:33:44:55');
      expect(restored.printer.deviceName, 'Rongta RP58');
      expect(restored.printer.wide, isTrue);
      expect(restored.printer.autoPrint, isTrue);
      expect(restored.printer.copies, 2);
    });

    test('printer settings default to unconfigured', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore.fromPrefs(prefs);
      expect(store.printer.isConfigured, isFalse);
      expect(store.printer.autoPrint, isFalse);
      expect(store.printer.copies, 1);
    });
  });

  group('AppStore backup', () {
    test('exportBackupJson/importBackup round-trips all data', () {
      final store = AppStore()
        ..updateStoreSettings(
          const StoreSettings(name: 'Toko Bahagia', phone: '08123'),
        );
      final product = _product(
        id: 'p1',
        name: 'Air Mineral',
        price: 3000,
        category: 'Minuman',
        stock: 10,
      );
      store.addProduct(product);
      store.openShift(50000);
      final cart = CartProvider();
      cart.addItem(product);
      cart.submitOrder(10000, store);
      store.addDebt(
        Debt(
          id: 'd1',
          type: DebtType.receivable,
          partyName: 'Budi',
          amount: 50000,
          createdAt: DateTime.now(),
        ),
      );

      final backup = store.exportBackupJson();
      expect(backup, contains('"version": 1'));

      final restored = AppStore();
      expect(restored.importBackup(backup), isTrue);
      expect(restored.settings.name, 'Toko Bahagia');
      expect(restored.products.single.id, 'p1');
      expect(restored.stockOf('p1'), 9);
      expect(restored.orders.single.items.single.quantity, 1);
      expect(restored.cashEntries, hasLength(1));
      expect(restored.debts.single.partyName, 'Budi');
      expect(restored.activeShift, isNotNull);
    });

    test('importBackup rejects invalid JSON without corrupting state', () {
      final store = AppStore();
      final product = _product(
        id: 'p1',
        name: 'Es Teh',
        price: 5000,
        category: 'Minuman',
      );
      store.addProduct(product);

      expect(store.importBackup('bukan json'), isFalse);
      expect(store.importBackup('{"products": "bukan-list"}'), isFalse);
      expect(store.products, [product]);
    });

    test('importBackup overrides existing data atomically', () {
      final store = AppStore();
      store.addProduct(
        _product(id: 'p1', name: 'Lama', price: 1000, category: 'Minuman'),
      );

      final source = AppStore()
        ..addProduct(
          _product(id: 'p2', name: 'Baru', price: 2000, category: 'Snack'),
        );
      final backup = source.exportBackupJson();

      expect(store.importBackup(backup), isTrue);
      expect(store.products.single.name, 'Baru');
      expect(store.products, hasLength(1));
    });

    test('importBackup refuses files that are not an aksy backup', () {
      final store = AppStore();
      store.addProduct(
        _product(id: 'p1', name: 'Lama', price: 1000, category: 'Minuman'),
      );
      store.updateStoreSettings(const StoreSettings(name: 'Toko Asli'));

      expect(store.importBackup('{}'), isFalse);
      expect(store.importBackup('{"foo": 1}'), isFalse);
      expect(store.importBackup('{"products": []}'), isFalse);
      expect(
        store.importBackup('{"version": 99, "products": []}'),
        isFalse,
      );

      expect(store.products, hasLength(1));
      expect(store.settings.name, 'Toko Asli');
    });
  });

  group('AppStore recovery', () {
    test('corrupt persisted data does not brick the app', () async {
      SharedPreferences.setMockInitialValues({
        'store.products': '[{"id":"p1","nama":"x"}]',
        'store.orders': 'bukan json',
        'store.cash_entries': '[1, 2, 3]',
        'store.debts': '{"bukan":"list"}',
        'store.shifts': '[]',
        'store.active_shift': '{rusak',
        'store.settings': 'bukan json',
      });
      final prefs = await SharedPreferences.getInstance();

      final store = AppStore.fromPrefs(prefs);

      expect(store.orders, isEmpty);
      expect(store.cashEntries, isEmpty);
      expect(store.debts, isEmpty);
      expect(store.activeShift, isNull);
      expect(store.products, isEmpty);
      expect(store.settings.name, isNotEmpty);
    });

    test('a single malformed record does not drop the whole collection', () async {
      SharedPreferences.setMockInitialValues({
        'store.products': jsonEncode([
          _product(id: 'p1', name: 'Good', price: 1000, category: 'Minuman').toJson(),
          {'id': 'p2'},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      final store = AppStore.fromPrefs(prefs);

      expect(store.products.map((p) => p.id), ['p1']);
    });
  });

  group('Shift cash reconciliation', () {
    test('expected cash accounts for cash in and cash out', () {
      final store = AppStore();
      final product = _product(
        id: 'p1',
        name: 'Es Teh',
        price: 5000,
        category: 'Minuman',
        stock: 10,
      );
      store.addProduct(product);
      final shift = store.openShift(100000);

      final cart = CartProvider()..addItem(product);
      cart.submitOrder(10000, store);
      store.addCashEntry(
        CashEntry(
          id: 'cf1',
          type: CashFlowType.cashOut,
          amount: 20000,
          category: 'Belanja Stok',
          createdAt: DateTime.now(),
        ),
      );

      expect(store.expectedCashForShift(shift), 100000 + 5000 - 20000);

      final closed = store.closeShift(85000);
      expect(closed?.expectedCash, 85000);
      expect(closed?.difference, 0);
    });
  });

  group('Date-based status flags', () {
    test('a debt is only overdue after its due date passes', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      Debt build(DateTime due) => Debt(
        id: 'd1',
        type: DebtType.receivable,
        partyName: 'Budi',
        amount: 10000,
        createdAt: now.subtract(const Duration(days: 5)),
        dueDate: due,
      );

      expect(build(today).isOverdue, isFalse);
      expect(
        build(today.add(const Duration(days: 1))).isOverdue,
        isFalse,
      );
      expect(
        build(today.subtract(const Duration(days: 1))).isOverdue,
        isTrue,
      );
      expect(build(now.subtract(const Duration(days: 1))).isOverdue, isTrue);
    });

    test('an already expired product counts as expiring soon', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      Product build(DateTime? expiry) => Product(
        id: 'p1',
        name: 'Susu',
        price: 5000,
        category: 'Minuman',
        icon: Icons.local_drink,
        stock: 5,
        costPrice: 3000,
        expiryDate: expiry,
      );

      expect(build(null).isExpiringSoon(), isFalse);
      expect(build(today.add(const Duration(days: 30))).isExpiringSoon(), isFalse);
      expect(build(today.add(const Duration(days: 14))).isExpiringSoon(), isTrue);
      expect(build(today).isExpiringSoon(), isTrue);
      expect(
        build(today.subtract(const Duration(days: 3))).isExpiringSoon(),
        isTrue,
      );
    });
  });

  group('Reports', () {
    test('top products keep sold items whose product was deleted', () {
      final store = AppStore();
      final product = _product(
        id: 'p1',
        name: 'Kopi Susu',
        price: 18000,
        category: 'Minuman',
        stock: 20,
      );
      store.addProduct(product);
      final cart = CartProvider()..addItem(product);
      cart.submitOrder(50000, store);
      store.removeProduct('p1');

      final top = store.topProductsOn(DateTime.now());
      expect(top, hasLength(1));
      expect(top.single.key.name, 'Kopi Susu');
      expect(top.single.value, 1);
    });
  });
}

Product _product({
  required String id,
  required String name,
  required int price,
  required String category,
  int stock = 100,
}) {
  return Product(
    id: id,
    name: name,
    price: price,
    category: category,
    icon: Icons.local_drink,
    stock: stock,
    costPrice: price ~/ 2,
  );
}

final Finder _cartPayButton = find.text('Bayar').first;

Future<void> _openDestination(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(NavigationDrawerDestination, label));
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required AppStore store,
  CartProvider? cart,
}) {
  return tester.pumpWidget(
    AppScope(
      store: store,
      child: CartScope(
        notifier: cart ?? CartProvider(),
        child: const MaterialApp(home: AppShellScreen()),
      ),
    ),
  );
}

final Finder _dialogBayar = find.descendant(
  of: find.byType(Dialog),
  matching: find.text('Bayar'),
);

Future<void> _openPaymentDialog(WidgetTester tester) async {
  await tester.tap(_cartPayButton);
  await tester.pumpAndSettle();
  expect(find.text('Pembayaran'), findsOneWidget);
}
