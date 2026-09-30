import 'package:flutter/material.dart';

abstract final class ProductIcons {
  static const List<IconData> catalog = [
    Icons.inventory_2,
    Icons.local_drink,
    Icons.lunch_dining,
    Icons.cookie_outlined,
    Icons.shopping_basket_outlined,
    Icons.cleaning_services_outlined,
    Icons.checkroom_outlined,
    Icons.face_retouching_natural,
    Icons.card_giftcard,
    Icons.spa_outlined,
    Icons.pets,
    Icons.home_outlined,
    Icons.local_hospital_outlined,
    Icons.fitness_center,
    Icons.menu_book_outlined,
    Icons.devices_other,
    Icons.category_outlined,
  ];

  static const IconData fallback = Icons.inventory_2;

  static IconData fromCodePoint(int? codePoint) {
    return switch (codePoint) {
      final int code when code == Icons.local_drink.codePoint =>
        Icons.local_drink,
      final int code when code == Icons.lunch_dining.codePoint =>
        Icons.lunch_dining,
      final int code when code == Icons.cookie_outlined.codePoint =>
        Icons.cookie_outlined,
      final int code when code == Icons.shopping_basket_outlined.codePoint =>
        Icons.shopping_basket_outlined,
      final int code
          when code == Icons.cleaning_services_outlined.codePoint =>
          Icons.cleaning_services_outlined,
      final int code when code == Icons.checkroom_outlined.codePoint =>
        Icons.checkroom_outlined,
      final int code when code == Icons.face_retouching_natural.codePoint =>
        Icons.face_retouching_natural,
      final int code when code == Icons.card_giftcard.codePoint =>
        Icons.card_giftcard,
      final int code when code == Icons.spa_outlined.codePoint =>
        Icons.spa_outlined,
      final int code when code == Icons.pets.codePoint => Icons.pets,
      final int code when code == Icons.home_outlined.codePoint =>
        Icons.home_outlined,
      final int code when code == Icons.local_hospital_outlined.codePoint =>
        Icons.local_hospital_outlined,
      final int code when code == Icons.fitness_center.codePoint =>
        Icons.fitness_center,
      final int code when code == Icons.menu_book_outlined.codePoint =>
        Icons.menu_book_outlined,
      final int code when code == Icons.devices_other.codePoint =>
        Icons.devices_other,
      final int code when code == Icons.category_outlined.codePoint =>
        Icons.category_outlined,
      _ => fallback,
    };
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.icon,
    this.wholesalePrice,
    this.minWholesaleQty,
    this.costPrice,
    this.barcode,
    this.imagePath,
    this.stock = 0,
    this.expiryDate,
    this.batchNumber,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      price: json['price'] as int,
      category: json['category'] as String? ?? 'Umum',
      icon: ProductIcons.fromCodePoint(json['icon'] as int?),
      wholesalePrice: json['wholesalePrice'] as int?,
      minWholesaleQty: json['minWholesaleQty'] as int?,
      costPrice: json['costPrice'] as int?,
      barcode: json['barcode'] as String?,
      imagePath: json['imagePath'] as String?,
      stock: json['stock'] as int? ?? 0,
      expiryDate: json['expiryDate'] == null
          ? null
          : DateTime.tryParse(json['expiryDate'] as String),
      batchNumber: json['batchNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'icon': icon.codePoint,
      'wholesalePrice': wholesalePrice,
      'minWholesaleQty': minWholesaleQty,
      'costPrice': costPrice,
      'barcode': barcode,
      'imagePath': imagePath,
      'stock': stock,
      'expiryDate': expiryDate?.toIso8601String(),
      'batchNumber': batchNumber,
    };
  }

  final String id;
  final String name;
  final int price;
  final String category;
  final IconData icon;
  final int? wholesalePrice;
  final int? minWholesaleQty;
  final int? costPrice;
  final String? barcode;
  final String? imagePath;
  final int stock;
  final DateTime? expiryDate;
  final String? batchNumber;

  bool get hasWholesaleTier =>
      wholesalePrice != null && minWholesaleQty != null;

  int? get profitMargin {
    if (costPrice == null) return null;
    return price - costPrice!;
  }

  int unitPriceFor(int quantity) {
    if (hasWholesaleTier && quantity >= minWholesaleQty!) {
      return wholesalePrice!;
    }
    return price;
  }

  bool isExpiringSoon([int withinDays = 14]) {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
      expiryDate!.year,
      expiryDate!.month,
      expiryDate!.day,
    );
    return !expiry.isAfter(today.add(Duration(days: withinDays)));
  }

  Product copyWith({
    String? name,
    int? price,
    String? category,
    IconData? icon,
    int? wholesalePrice,
    int? minWholesaleQty,
    int? costPrice,
    String? barcode,
    String? imagePath,
    int? stock,
    DateTime? expiryDate,
    String? batchNumber,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      minWholesaleQty: minWholesaleQty ?? this.minWholesaleQty,
      costPrice: costPrice ?? this.costPrice,
      barcode: barcode ?? this.barcode,
      imagePath: imagePath ?? this.imagePath,
      stock: stock ?? this.stock,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
    );
  }
}