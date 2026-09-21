import 'cart_item.dart';

class Order {
  const Order({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.paidAmount,
  });

  final String id;
  final DateTime createdAt;
  final List<CartItem> items;
  final int paidAmount;

  int get total => items.fold(0, (sum, item) => sum + item.subtotal);

  int get change => paidAmount - total;
}