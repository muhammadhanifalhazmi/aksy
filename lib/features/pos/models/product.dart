import 'package:flutter/material.dart';

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
      icon: IconData(json['icon'] as int),
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
    final diff = expiryDate!.difference(DateTime.now()).inDays;
    return diff <= withinDays;
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