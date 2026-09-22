import 'product.dart';

class CartItem {
  const CartItem({required this.product, required this.quantity});

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