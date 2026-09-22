import 'package:flutter/material.dart';

import '../models/product.dart';

class SeedData {
  SeedData._();

  static const List<String> categories = [
    'Minuman',
    'Makanan',
    'Snack',
    'Sembako',
  ];

  static final List<Product> products = [
    const Product(
      id: 'p01',
      name: 'Kopi Susu Aren',
      price: 18000,
      category: 'Minuman',
      icon: Icons.coffee,
      wholesalePrice: 16500,
      minWholesaleQty: 5,
      costPrice: 12000,
      stock: 24,
    ),
    const Product(
      id: 'p02',
      name: 'Es Kopi Susu',
      price: 15000,
      category: 'Minuman',
      icon: Icons.local_cafe,
      costPrice: 10000,
      stock: 18,
    ),
    const Product(
      id: 'p03',
      name: 'Es Teh Manis',
      price: 5000,
      category: 'Minuman',
      icon: Icons.local_drink,
      costPrice: 2500,
      stock: 40,
    ),
    const Product(
      id: 'p04',
      name: 'Air Mineral',
      price: 3000,
      category: 'Minuman',
      icon: Icons.water_drop,
      wholesalePrice: 2700,
      minWholesaleQty: 12,
      costPrice: 1800,
      barcode: '8991001234567',
      stock: 120,
    ),
    const Product(
      id: 'p05',
      name: 'Nasi Goreng',
      price: 20000,
      category: 'Makanan',
      icon: Icons.rice_bowl,
      costPrice: 14000,
      stock: 15,
    ),
    const Product(
      id: 'p06',
      name: 'Mie Goreng',
      price: 15000,
      category: 'Makanan',
      icon: Icons.ramen_dining,
      costPrice: 10000,
      stock: 20,
    ),
    Product(
      id: 'p07',
      name: 'Indomie Rebus',
      price: 8000,
      category: 'Makanan',
      icon: Icons.soup_kitchen,
      wholesalePrice: 7200,
      minWholesaleQty: 10,
      costPrice: 5500,
      barcode: '8991002345678',
      stock: 60,
      batchNumber: 'IN-2026-01',
      expiryDate: _expiry(2026, 12, 31),
    ),
    const Product(
      id: 'p08',
      name: 'Roti Bakar',
      price: 12000,
      category: 'Snack',
      icon: Icons.bakery_dining,
      costPrice: 7500,
      stock: 12,
    ),
    const Product(
      id: 'p09',
      name: 'Kentang Goreng',
      price: 10000,
      category: 'Snack',
      icon: Icons.fastfood,
      costPrice: 6000,
      stock: 14,
    ),
    const Product(
      id: 'p10',
      name: 'Roti Coklat',
      price: 8000,
      category: 'Snack',
      icon: Icons.cookie,
      costPrice: 4500,
      stock: 0,
      barcode: '8991003456789',
    ),
  ];

  static DateTime _expiry(int year, int month, int day) {
    return DateTime(year, month, day);
  }
}