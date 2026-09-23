import 'product.dart';

class CartItem {
  const CartItem({required this.product, required this.quantity});

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(
        json['product'] as Map<String, dynamic>,
      ),
      quantity: json['quantity'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
    };
  }

  final Product product;
  final int quantity;

  int get unitPrice => product.unitPriceFor(quantity);

  bool get isWholesale => unitPrice != product.price;

  int get subtotal => unitPrice * quantity;

  int? get estimatedProfit {
    final cost = product.costPrice;
    if (cost == null) return null;
    return (unitPrice - cost) * quantity;
  }

  CartItem copyWith({int? quantity}) {
    return CartItem(product: product, quantity: quantity ?? this.quantity);
  }
}