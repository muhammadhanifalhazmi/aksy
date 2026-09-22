import 'cart_item.dart';

class Order {
  const Order({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.paidAmount,
    this.discount = 0,
  });

  final String id;
  final DateTime createdAt;
  final List<CartItem> items;
  final int paidAmount;
  final int discount;

  int get itemsTotal => items.fold(0, (sum, item) => sum + item.subtotal);

  int get total => itemsTotal - discount;

  int get change => paidAmount - total;
}