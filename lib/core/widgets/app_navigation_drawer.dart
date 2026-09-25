import 'package:flutter/material.dart';

import '../data/app_store.dart';

enum AppDestination { pos, inventory, cashFlow, debt, shift, reports }

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = AppScope.of(context);
    return NavigationDrawer(
      selectedIndex: selectedDestination.index,
      onDestinationSelected: (index) {
        final destination = AppDestination.values[index];
        Navigator.of(context, rootNavigator: true).pop();
        if (destination != selectedDestination) {
          onDestinationSelected(destination);
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Image(
                    image: AssetImage('assets/images/icon.png'),
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Aplikasi Kasir Easy',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                store.activeShift == null
                    ? 'Shift belum dibuka'
                    : 'Shift ${store.activeShift!.id} aktif',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: store.activeShift == null
                      ? theme.colorScheme.outline
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.point_of_sale),
          label: Expanded(child: Text('POS')),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: Expanded(child: Text('Inventori')),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          label: Expanded(child: Text('Kas Masuk / Keluar')),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: Expanded(child: Text('Hutang & Piutang')),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.history),
          label: Expanded(child: Text('Shift Kasir')),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.summarize_outlined),
          label: Expanded(child: Text('Laporan')),
        ),
      ],
    );
  }
}
