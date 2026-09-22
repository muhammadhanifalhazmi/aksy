import 'package:flutter/widgets.dart';

import '../../../core/data/app_store.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);

  int quantityOf(String productId) {
    final index = _indexOf(productId);
    return index < 0 ? 0 : _items[index].quantity;
  }

  void addItem(Product product, {int availableStock = 0x7FFFFFFF}) {
    if (quantityOf(product.id) >= availableStock) return;
    final index = _indexOf(product.id);
    if (index < 0) {
      _items.add(CartItem(product: product, quantity: 1));
    } else {
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity + 1,
      );
    }
    notifyListeners();
  }

  void increment(String productId, {int availableStock = 0x7FFFFFFF}) {
    final index = _indexOf(productId);
    if (index < 0) return;
    if (_items[index].quantity >= availableStock) return;
    _items[index] = _items[index].copyWith(
      quantity: _items[index].quantity + 1,
    );
    notifyListeners();
  }

  void decrement(String productId) {
    final index = _indexOf(productId);
    if (index < 0) return;
    if (_items[index].quantity <= 1) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity - 1,
      );
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    final index = _indexOf(productId);
    if (index < 0) return;
    _items.removeAt(index);
    notifyListeners();
  }

  int changeFor(int cashReceived) => cashReceived - subtotal;

  Order submitOrder(int paidAmount, AppStore store, {int discount = 0}) {
    final order = Order(
      id: 'TRX${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      items: List.of(_items),
      paidAmount: paidAmount,
      discount: discount,
    );
    store.recordOrder(order);
    _items.clear();
    notifyListeners();
    return order;
  }

  int _indexOf(String productId) {
    return _items.indexWhere((item) => item.product.id == productId);
  }
}

class CartScope extends InheritedNotifier<CartProvider> {
  const CartScope({
    super.key,
    required CartProvider notifier,
    required super.child,
  }) : super(notifier: notifier);

  static CartProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
    assert(scope != null, 'CartScope not found above this context');
    return scope!.notifier!;
  }
}