import 'package:flutter/material.dart';

import 'core/data/app_store.dart';
import 'core/theme/app_theme.dart';
import 'features/pos/providers/cart_provider.dart';
import 'features/splash/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  runApp(AksyApp(store: store));
}

class AksyApp extends StatelessWidget {
  const AksyApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
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