import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aksy/core/utils/currency_formatter.dart';
import 'package:aksy/features/pos/models/product.dart';
import 'package:aksy/features/pos/providers/cart_provider.dart';

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

    test('submitOrder clears cart and computes change', () {
      final cart = CartProvider();
      final product = _product(
        id: 'p1',
        name: 'Roti Bakar',
        price: 12000,
        category: 'Snack',
      );
      cart.addItem(product);
      final order = cart.submitOrder(20000);
      expect(order.total, 12000);
      expect(order.change, 8000);
      expect(cart.isEmpty, isTrue);
    });
  });
}

Product _product({
  required String id,
  required String name,
  required int price,
  required String category,
}) {
  return Product(
    id: id,
    name: name,
    price: price,
    category: category,
    icon: Icons.local_drink,
  );
}