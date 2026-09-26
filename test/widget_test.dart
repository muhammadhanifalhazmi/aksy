import 'package:aksy/app_shell_screen.dart';
import 'package:aksy/core/data/app_store.dart';
import 'package:aksy/core/utils/currency_formatter.dart';
import 'package:aksy/core/widgets/app_navigation_drawer.dart';
import 'package:aksy/features/chatbot/services/assistant_config.dart';
import 'package:aksy/features/chatbot/services/store_context.dart';
import 'package:aksy/features/debt/models/debt.dart';
import 'package:aksy/features/pos/models/cart_item.dart';
import 'package:aksy/features/pos/models/order.dart';
import 'package:aksy/features/pos/models/product.dart';
import 'package:aksy/features/pos/providers/cart_provider.dart';
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
      await selectDestination('Laporan');
      expect(find.text('Laporan'), findsOneWidget);
      await selectDestination('Asisten Kasir');
      expect(find.text('Asisten Kasir'), findsOneWidget);
      expect(find.text('Tanya apa saja tentang tokomu'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      final drawers = tester.widgetList<NavigationDrawer>(
        find.byType(NavigationDrawer, skipOffstage: false),
      );
      expect(drawers, isNotEmpty);
      expect(
        drawers.any(
          (drawer) => drawer.selectedIndex == AppDestination.assistant.index,
        ),
        isTrue,
      );
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

      await tester.pumpWidget(
        AppScope(
          store: store,
          child: CartScope(
            notifier: cart,
            child: const MaterialApp(home: AppShellScreen()),
          ),
        ),
      );

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
      expect(store.productByBarcode('000'), isNull);
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
  });

  group('StoreContext', () {
    test('summarises sales, shift, stock and debts for the assistant', () {
      final kopi = _product(
        id: 'p1',
        name: 'Kopi Susu',
        price: 18000,
        category: 'Minuman',
        stock: 5,
      );
      final teh = _product(
        id: 'p2',
        name: 'Es Teh',
        price: 5000,
        category: 'Minuman',
      );
      final roti = _product(
        id: 'p3',
        name: 'Roti Bakar',
        price: 12000,
        category: 'Snack',
        stock: 3,
      );

      final store = AppStore(products: [kopi, teh, roti])..openShift(50000);
      store.recordOrder(
        Order(
          id: 'o1',
          createdAt: DateTime.now(),
          items: [
            CartItem(product: kopi, quantity: 2),
            CartItem(product: teh, quantity: 1),
          ],
          paidAmount: 41000,
        ),
      );
      store.addDebt(
        Debt(
          id: 'd1',
          type: DebtType.receivable,
          partyName: 'Bu Sari',
          amount: 50000,
          createdAt: DateTime.now(),
          dueDate: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );

      final context = StoreContext.build(store);

      expect(context, contains('Omzet: Rp 41.000'));
      expect(context, contains('Transaksi: 1'));
      expect(context, contains('Estimasi laba: Rp 20.500'));
      expect(context, contains('Kas awal: Rp 50.000'));
      expect(context, contains('Kopi Susu: 2 pcs'));
      expect(context, contains('Roti Bakar (3)'));
      expect(context, contains('Stok habis: 0'));
      expect(context, contains('Total piutang: Rp 50.000'));
      expect(context, contains('Piutang lewat jatuh tempo: 1'));
      expect(context, contains('Terlambat: Bu Sari'));
    });

    test('reports no sales and closed shift on an empty store', () {
      final context = StoreContext.build(AppStore());

      expect(context, contains('Omzet: Rp 0'));
      expect(context, contains('Belum ada penjualan hari ini.'));
      expect(context, contains('Tidak ada shift yang sedang dibuka.'));
    });
  });

  group('AssistantConfig', () {
    test('normalizeBaseUrl adds a scheme and strips trailing slashes', () {
      expect(
        AssistantConfig.normalizeBaseUrl('  Example.workers.dev/  '),
        'https://Example.workers.dev',
      );
      expect(
        AssistantConfig.normalizeBaseUrl('http://10.0.2.2:8787//'),
        'http://10.0.2.2:8787',
      );
      expect(AssistantConfig.normalizeBaseUrl('   '), '');
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
