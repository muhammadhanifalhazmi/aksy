import 'package:flutter/material.dart';

import '../models/product.dart';

class SeedData {
  SeedData._();

  static const List<String> categories = [
    'Semua',
    'Minuman',
    'Makanan',
    'Snack',
  ];

  static const List<Product> products = [
    Product(
      id: 'p01',
      name: 'Kopi Susu Aren',
      price: 18000,
      category: 'Minuman',
      icon: Icons.coffee,
    ),
    Product(
      id: 'p02',
      name: 'Es Kopi Susu',
      price: 15000,
      category: 'Minuman',
      icon: Icons.local_cafe,
    ),
    Product(
      id: 'p03',
      name: 'Es Teh Manis',
      price: 5000,
      category: 'Minuman',
      icon: Icons.local_drink,
    ),
    Product(
      id: 'p04',
      name: 'Air Mineral',
      price: 3000,
      category: 'Minuman',
      icon: Icons.water_drop,
    ),
    Product(
      id: 'p05',
      name: 'Nasi Goreng',
      price: 20000,
      category: 'Makanan',
      icon: Icons.rice_bowl,
    ),
    Product(
      id: 'p06',
      name: 'Mie Goreng',
      price: 15000,
      category: 'Makanan',
      icon: Icons.ramen_dining,
    ),
    Product(
      id: 'p07',
      name: 'Indomie Rebus',
      price: 8000,
      category: 'Makanan',
      icon: Icons.soup_kitchen,
    ),
    Product(
      id: 'p08',
      name: 'Roti Bakar',
      price: 12000,
      category: 'Snack',
      icon: Icons.bakery_dining,
    ),
    Product(
      id: 'p09',
      name: 'Kentang Goreng',
      price: 10000,
      category: 'Snack',
      icon: Icons.fastfood,
    ),
    Product(
      id: 'p10',
      name: 'Roti Coklat',
      price: 8000,
      category: 'Snack',
      icon: Icons.cookie,
    ),
  ];

  static List<Product> productsByCategory(String category) {
    if (category.isEmpty || category == 'Semua') {
      return List.of(products);
    }
    return products.where((p) => p.category == category).toList();
  }
}