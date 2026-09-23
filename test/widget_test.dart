import 'package:aksy/core/data/app_store.dart';
import 'package:aksy/core/utils/currency_formatter.dart';
import 'package:aksy/features/debt/models/debt.dart';
import 'package:aksy/features/pos/models/product.dart';
import 'package:aksy/features/pos/providers/cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('recordDebtPayment supports partial payment and updates cash flow',
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