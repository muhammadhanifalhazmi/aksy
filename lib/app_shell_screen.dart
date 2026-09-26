import 'package:flutter/material.dart';

import 'core/widgets/app_navigation_drawer.dart';
import 'features/cash_flow/screens/cash_flow_screen.dart';
import 'features/debt/screens/debt_screen.dart';
import 'features/inventory/screens/inventory_screen.dart';
import 'features/pos/screens/pos_main_screen.dart';
import 'features/reports/screens/reports_screen.dart';
import 'features/shift/screens/shift_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  AppDestination _selectedDestination = AppDestination.pos;

  void _selectDestination(AppDestination destination) {
    if (destination == _selectedDestination) return;
    setState(() => _selectedDestination = destination);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedDestination == AppDestination.pos,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedDestination != AppDestination.pos) {
          _selectDestination(AppDestination.pos);
        }
      },
      child: IndexedStack(
        index: _selectedDestination.index,
        children: [
          POSMainScreen(
            selectedDestination: _selectedDestination,
            onDestinationSelected: _selectDestination,
          ),
          InventoryScreen(
            selectedDestination: _selectedDestination,
            onDestinationSelected: _selectDestination,
          ),
          CashFlowScreen(
            selectedDestination: _selectedDestination,
            onDestinationSelected: _selectDestination,
          ),
          DebtScreen(
            selectedDestination: _selectedDestination,
            onDestinationSelected: _selectDestination,
          ),
          ShiftScreen(
            selectedDestination: _selectedDestination,
            onDestinationSelected: _selectDestination,
          ),
          ReportsScreen(
            selectedDestination: _selectedDestination,
            onDestinationSelected: _selectDestination,
          ),
        ],
      ),
    );
  }
}
