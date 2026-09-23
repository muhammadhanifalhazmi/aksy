import 'cart_item.dart';

class Order {
  const Order({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.paidAmount,
    this.discount = 0,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List<dynamic>)
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      paidAmount: json['paidAmount'] as int,
      discount: json['discount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
      'paidAmount': paidAmount,
      'discount': discount,
    };
  }

  final String id;
  final DateTime createdAt;
  final List<CartItem> items;
  final int paidAmount;
  final int discount;

  int get itemsTotal => items.fold(0, (sum, item) => sum + item.subtotal);

  int get total => itemsTotal - discount;

  int get change => paidAmount - total;
}