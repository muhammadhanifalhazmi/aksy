import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/pos/providers/cart_provider.dart';
import 'features/pos/screens/pos_main_screen.dart';

void main() {
  runApp(const AksyApp());
}

class AksyApp extends StatelessWidget {
  const AksyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CartScope(
      notifier: CartProvider(),
      child: MaterialApp(
        title: 'Aksy POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const POSMainScreen(),
      ),
    );
  }
}