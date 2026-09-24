import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/cash_flow/models/cash_entry.dart';
import '../../features/debt/models/debt.dart';
import '../../features/pos/models/order.dart';
import '../../features/pos/models/product.dart';
import '../../features/shift/models/shift_record.dart';

class AppStore extends ChangeNotifier {
  AppStore({List<Product>? products, SharedPreferences? prefs})
      : _prefs = prefs,
        _products = List.of(products ?? const <Product>[]);

  static const _kProducts = 'store.products';
  static const _kOrders = 'store.orders';
  static const _kCashEntries = 'store.cash_entries';
  static const _kDebts = 'store.debts';
  static const _kShifts = 'store.shifts';
  static const _kActiveShift = 'store.active_shift';

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStore.fromPrefs(prefs);
  }

  factory AppStore.fromPrefs(SharedPreferences prefs) {
    final store = AppStore(prefs: prefs);
    store._restore(prefs);
    return store;
  }

  final SharedPreferences? _prefs;
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

  void _restore(SharedPreferences prefs) {
    List<dynamic> decode(String key) {
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return const [];
      return jsonDecode(raw) as List<dynamic>;
    }

    _products.addAll(
      decode(_kProducts)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    _orders.addAll(
      decode(_kOrders)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    _cashEntries.addAll(
      decode(_kCashEntries)
          .map((e) => CashEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    _debts.addAll(
      decode(_kDebts)
          .map((e) => Debt.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    _shifts.addAll(
      decode(_kShifts)
          .map((e) => ShiftRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    final activeRaw = prefs.getString(_kActiveShift);
    if (activeRaw != null && activeRaw.isNotEmpty) {
      _activeShift =
          ShiftRecord.fromJson(jsonDecode(activeRaw) as Map<String, dynamic>);
    }
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    String encode(List<dynamic> list) => jsonEncode(list);

    prefs.setString(
      _kProducts,
      encode(_products.map((p) => p.toJson()).toList()),
    );
    prefs.setString(
      _kOrders,
      encode(_orders.map((o) => o.toJson()).toList()),
    );
    prefs.setString(
      _kCashEntries,
      encode(_cashEntries.map((e) => e.toJson()).toList()),
    );
    prefs.setString(
      _kDebts,
      encode(_debts.map((d) => d.toJson()).toList()),
    );
    prefs.setString(
      _kShifts,
      encode(_shifts.map((s) => s.toJson()).toList()),
    );
    prefs.setString(
      _kActiveShift,
      _activeShift == null ? '' : jsonEncode(_activeShift!.toJson()),
    );
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
    _save();
    notifyListeners();
  }

  void updateProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index < 0) return;
    _products[index] = product;
    _save();
    notifyListeners();
  }

  void updateStock(String productId, int stock) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return;
    final current = _products[index];
    _products[index] = current.copyWith(stock: stock);
    _save();
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
    _save();
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

  List<Order> ordersBetween(DateTime start, DateTime endExclusive) {
    return _orders
        .where(
          (o) => !o.createdAt.isBefore(start) && o.createdAt.isBefore(endExclusive),
        )
        .toList();
  }

  int omzetBetween(DateTime start, DateTime endExclusive) {
    return ordersBetween(start, endExclusive).fold(0, (sum, o) => sum + o.total);
  }

  int transactionCountBetween(DateTime start, DateTime endExclusive) {
    return ordersBetween(start, endExclusive).length;
  }

  int itemsSoldBetween(DateTime start, DateTime endExclusive) {
    return ordersBetween(start, endExclusive).fold(
      0,
      (sum, o) => sum + o.items.fold(0, (s, i) => s + i.quantity),
    );
  }

  int estimatedProfitBetween(DateTime start, DateTime endExclusive) {
    var total = 0;
    for (final order in ordersBetween(start, endExclusive)) {
      for (final item in order.items) {
        total += item.estimatedProfit ?? 0;
      }
    }
    return total;
  }

  int cashInBetween(DateTime start, DateTime endExclusive) {
    return _cashEntries
        .where(
          (e) =>
              e.type == CashFlowType.cashIn &&
              !e.createdAt.isBefore(start) &&
              e.createdAt.isBefore(endExclusive),
        )
        .fold(0, (sum, e) => sum + e.amount);
  }

  int cashOutBetween(DateTime start, DateTime endExclusive) {
    return _cashEntries
        .where(
          (e) =>
              e.type == CashFlowType.cashOut &&
              !e.createdAt.isBefore(start) &&
              e.createdAt.isBefore(endExclusive),
        )
        .fold(0, (sum, e) => sum + e.amount);
  }

  List<MapEntry<Product, int>> topProductsBetween(
    DateTime start,
    DateTime endExclusive, {
    int limit = 10,
  }) {
    final totals = <String, int>{};
    for (final order in ordersBetween(start, endExclusive)) {
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

  List<MapEntry<String, int>> categoryRevenueBetween(
    DateTime start,
    DateTime endExclusive,
  ) {
    final totals = <String, int>{};
    for (final order in ordersBetween(start, endExclusive)) {
      for (final item in order.items) {
        totals.update(
          item.product.category,
          (value) => value + item.subtotal,
          ifAbsent: () => item.subtotal,
        );
      }
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  List<DailyAggregate> dailyAggregatesBetween(
    DateTime start,
    DateTime endExclusive,
  ) {
    final result = <DailyAggregate>[];
    var cursor = DateTime(start.year, start.month, start.day);
    while (cursor.isBefore(endExclusive)) {
      final next = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final dayOrders = ordersBetween(cursor, next);
      var profit = 0;
      var items = 0;
      for (final order in dayOrders) {
        for (final item in order.items) {
          profit += item.estimatedProfit ?? 0;
          items += item.quantity;
        }
      }
      result.add(
        DailyAggregate(
          date: cursor,
          transactions: dayOrders.length,
          items: items,
          omzet: dayOrders.fold(0, (sum, o) => sum + o.total),
          profit: profit,
          cashIn: cashInBetween(cursor, next),
          cashOut: cashOutBetween(cursor, next),
        ),
      );
      cursor = next;
    }
    return result;
  }

  void addCashEntry(CashEntry entry) {
    _cashEntries.add(entry);
    _save();
    notifyListeners();
  }

  void addDebt(Debt debt) {
    _debts.add(debt);
    _save();
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
    _save();
    notifyListeners();
  }

  ShiftRecord openShift(int startingCash) {
    final shift = ShiftRecord(
      id: 'SFT${DateTime.now().millisecondsSinceEpoch}',
      openTime: DateTime.now(),
      startingCash: startingCash,
    );
    _activeShift = shift;
    _save();
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
    _save();
    notifyListeners();
    return closed;
  }
}

class DailyAggregate {
  const DailyAggregate({
    required this.date,
    required this.transactions,
    required this.items,
    required this.omzet,
    required this.profit,
    required this.cashIn,
    required this.cashOut,
  });

  final DateTime date;
  final int transactions;
  final int items;
  final int omzet;
  final int profit;
  final int cashIn;
  final int cashOut;

  DailyAggregate operator +(covariant DailyAggregate other) {
    return DailyAggregate(
      date: other.date,
      transactions: transactions + other.transactions,
      items: items + other.items,
      omzet: omzet + other.omzet,
      profit: profit + other.profit,
      cashIn: cashIn + other.cashIn,
      cashOut: cashOut + other.cashOut,
    );
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