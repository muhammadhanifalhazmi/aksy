import 'package:flutter/material.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.icon,
  });

  final String id;
  final String name;
  final int price;
  final String category;
  final IconData icon;
}