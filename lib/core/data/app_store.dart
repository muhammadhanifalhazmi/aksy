import 'package:flutter/widgets.dart';

import '../../features/cash_flow/models/cash_entry.dart';
import '../../features/debt/models/debt.dart';
import '../../features/pos/data/seed_data.dart';
import '../../features/pos/models/order.dart';
import '../../features/pos/models/product.dart';
import '../../features/shift/models/shift_record.dart';

class AppStore extends ChangeNotifier {
  AppStore({List<Product>? products}) : _products = List.of(products ?? SeedData.products);

  final List<Product> _products;
  final List<Order> _orders = [];
  final List<CashEntry> _cashEntries = [];
  final List<Debt> _debts = [];
  final List<ShiftRecord> _shifts = [];
  ShiftRecord? _activeShift;

  List<Product> get products => List.unmodifiable(_products);
  List<Order> get orders => List.unmodifiable(_orders);
  List<CashEntry> get cashEntries => List.unmodifiable(_cashEntries);
  List<Debt> get debts => List.unmodifiable(_debts);
  List<ShiftRecord> get shifts => List.unmodifiable(_shifts);
  ShiftRecord? get activeShift => _activeShift;

  List<String> get categories {
    final seen = <String>{};
    for (final product in _products) {
      if (product.category.isNotEmpty) seen.add(product.category);
    }
    return List.unmodifiable(seen);
  }

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  Product? productByBarcode(String barcode) {
    final trimmed = barcode.trim();
    for (final product in _products) {
      if (product.barcode != null && product.barcode == trimmed) return product;
    }
    return null;
  }

  int stockOf(String productId) {
    return productById(productId)?.stock ?? 0;
  }

  void addProduct(Product product) {
    _products.add(product);
    notifyListeners();
  }

  void updateProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index < 0) return;
    _products[index] = product;
    notifyListeners();
  }

  void updateStock(String productId, int stock) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return;
    final current = _products[index];
    _products[index] = current.copyWith(stock: stock);
    notifyListeners();
  }

  void deductStock(String productId, int quantity) {
    final product = productById(productId);
    if (product == null || quantity <= 0) return;
    final remaining = product.stock - quantity;
    updateStock(productId, remaining < 0 ? 0 : remaining);
  }

  void recordOrder(Order order) {
    for (final item in order.items) {
      deductStock(item.product.id, item.quantity);
    }
    _orders.add(order);
    _cashEntries.add(
      CashEntry(
        id: 'CF${DateTime.now().millisecondsSinceEpoch}',
        type: CashFlowType.cashIn,
        amount: order.total,
        category: 'Penjualan',
        note: 'Transaksi ${order.id}',
        createdAt: order.createdAt,
      ),
    );
    notifyListeners();
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Order> ordersOn(DateTime day) {
    return _orders.where((o) => isSameDay(o.createdAt, day)).toList();
  }

  int omzetOn(DateTime day) {
    return ordersOn(day).fold(0, (sum, o) => sum + o.total);
  }

  int transactionCountOn(DateTime day) => ordersOn(day).length;

  int itemsSoldOn(DateTime day) {
    return ordersOn(day).fold(
      0,
      (sum, o) => sum + o.items.fold(0, (s, i) => s + i.quantity),
    );
  }

  int estimatedProfitOn(DateTime day) {
    var total = 0;
    for (final order in ordersOn(day)) {
      for (final item in order.items) {
        total += item.estimatedProfit ?? 0;
      }
    }
    return total;
  }

  List<CashEntry> cashEntriesOn(DateTime day) {
    return _cashEntries.where((e) => isSameDay(e.createdAt, day)).toList();
  }

  int cashInOn(DateTime day) {
    return cashEntriesOn(day)
        .where((e) => e.type == CashFlowType.cashIn)
        .fold(0, (sum, e) => sum + e.amount);
  }

  int cashOutOn(DateTime day) {
    return cashEntriesOn(day)
        .where((e) => e.type == CashFlowType.cashOut)
        .fold(0, (sum, e) => sum + e.amount);
  }

  List<MapEntry<Product, int>> topProductsOn(DateTime day, {int limit = 5}) {
    final totals = <String, int>{};
    for (final order in ordersOn(day)) {
      for (final item in order.items) {
        totals.update(
          item.product.id,
          (value) => value + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <MapEntry<Product, int>>[];
    for (final entry in sorted.take(limit)) {
      final product = productById(entry.key);
      if (product != null) result.add(MapEntry(product, entry.value));
    }
    return result;
  }

  void addCashEntry(CashEntry entry) {
    _cashEntries.add(entry);
    notifyListeners();
  }

  void addDebt(Debt debt) {
    _debts.add(debt);
    notifyListeners();
  }

  void recordDebtPayment(String debtId, int amount) {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index < 0 || amount <= 0) return;
    final debt = _debts[index];
    if (debt.isPaid || amount > debt.remaining) return;
    final at = DateTime.now();
    final payment = DebtPayment(
      id: 'PAY${at.millisecondsSinceEpoch}',
      amount: amount,
      at: at,
    );
    _debts[index] = debt.copyWith(
      paidAmount: debt.paidAmount + amount,
      payments: [...debt.payments, payment],
    );
    _cashEntries.add(
      CashEntry(
        id: 'CF${at.millisecondsSinceEpoch}',
        type: debt.type == DebtType.receivable
            ? CashFlowType.cashIn
            : CashFlowType.cashOut,
        amount: amount,
        category: debt.type == DebtType.receivable
            ? 'Pembayaran Piutang'
            : 'Pembayaran Hutang',
        note: debt.partyName,
        createdAt: at,
      ),
    );
    notifyListeners();
  }

  ShiftRecord openShift(int startingCash) {
    final shift = ShiftRecord(
      id: 'SFT${DateTime.now().millisecondsSinceEpoch}',
      openTime: DateTime.now(),
      startingCash: startingCash,
    );
    _activeShift = shift;
    notifyListeners();
    return shift;
  }

  int totalSalesSince(DateTime since) {
    return _orders
        .where((o) => !o.createdAt.isBefore(since))
        .fold(0, (sum, o) => sum + o.total);
  }

  List<Order> currentShiftSales() {
    final shift = _activeShift;
    if (shift == null) return const [];
    return _orders
        .where((o) => !o.createdAt.isBefore(shift.openTime))
        .toList();
  }

  ShiftRecord? closeShift(int actualCash, {String? note}) {
    final shift = _activeShift;
    if (shift == null) return null;
    final sales = totalSalesSince(shift.openTime);
    final expected = shift.startingCash + sales;
    final closed = ShiftRecord(
      id: shift.id,
      openTime: shift.openTime,
      startingCash: shift.startingCash,
      expectedCash: expected,
      actualCash: actualCash,
      note: note,
      closeTime: DateTime.now(),
    );
    _shifts.add(closed);
    _activeShift = null;
    notifyListeners();
    return closed;
  }
}

class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found above this context');
    return scope!.notifier!;
  }
}