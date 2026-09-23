import 'package:flutter/material.dart';

import 'core/data/app_store.dart';
import 'core/theme/app_theme.dart';
import 'features/pos/providers/cart_provider.dart';
import 'features/splash/screens/splash_screen.dart';

void main() {
  runApp(const AksyApp());
}

class AksyApp extends StatelessWidget {
  const AksyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: AppStore(),
      child: CartScope(
        notifier: CartProvider(),
        child: MaterialApp(
          title: 'Aplikasi Kasir Easy',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}