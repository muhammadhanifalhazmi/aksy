import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aksy/core/data/app_store.dart';
import 'package:aksy/features/pos/models/cart_item.dart';
import 'package:aksy/features/pos/models/order.dart';
import 'package:aksy/features/pos/models/product.dart';
import 'package:aksy/features/reports/models/report_period.dart';
import 'package:aksy/features/reports/services/report_pdf_generator.dart';

void main() {
  group('ReportPeriod', () {
    test('computes start and end for each type', () {
      final anchor = DateTime(2026, 5, 15);

      final daily = ReportPeriod(type: ReportPeriodType.daily, anchor: anchor);
      expect(daily.start, DateTime(2026, 5, 15));
      expect(daily.end, DateTime(2026, 5, 15));

      final weekly = ReportPeriod(type: ReportPeriodType.weekly, anchor: anchor);
      expect(weekly.start, DateTime(2026, 5, 11));
      expect(weekly.end, DateTime(2026, 5, 17));

      final monthly = ReportPeriod(type: ReportPeriodType.monthly, anchor: anchor);
      expect(monthly.start, DateTime(2026, 5, 1));
      expect(monthly.end, DateTime(2026, 5, 31));

      final quarterly =
          ReportPeriod(type: ReportPeriodType.quarterly, anchor: anchor);
      expect(quarterly.start, DateTime(2026, 4, 1));
      expect(quarterly.end, DateTime(2026, 6, 30));

      final yearly = ReportPeriod(type: ReportPeriodType.yearly, anchor: anchor);
      expect(yearly.start, DateTime(2026, 1, 1));
      expect(yearly.end, DateTime(2026, 12, 31));
    });

    test('aggregates orders across the selected period', () {
      final store = _buildStoreWithOrders();
      final now = DateTime.now();
      final month = ReportPeriod(
        type: ReportPeriodType.monthly,
        anchor: DateTime(now.year, now.month, 15),
      );
      final omzet = store.omzetBetween(month.start, month.endExclusive);
      expect(omzet, greaterThan(0));
      expect(
        store.transactionCountBetween(month.start, month.endExclusive),
        2,
      );
      expect(store.itemsSoldBetween(month.start, month.endExclusive), 4);
    });
  });

  group('generateReportPdf', () {
    test('produces a non-empty PDF for every period type', () async {
      final store = _buildStoreWithOrders();
      final anchor = DateTime.now();

      for (final type in ReportPeriodType.values) {
        final period = ReportPeriod(type: type, anchor: anchor);
        final bytes = await generateReportPdf(store: store, period: period);
        expect(bytes, isA<Uint8List>());
        expect(bytes, isNotEmpty);
      }
    });

    test('produces a valid PDF when there is no data', () async {
      final store = AppStore(products: []);
      final period = ReportPeriod(
        type: ReportPeriodType.monthly,
        anchor: DateTime.now(),
      );
      final bytes = await generateReportPdf(store: store, period: period);
      expect(bytes, isNotEmpty);
    });
  });
}

AppStore _buildStoreWithOrders() {
  final now = DateTime.now();
  final day5 = DateTime(now.year, now.month, 5);
  final day20 = DateTime(now.year, now.month, 20);
  final drink = Product(
    id: 'p1',
    name: 'Es Teh',
    price: 5000,
    category: 'Minuman',
    icon: Icons.local_drink,
    stock: 1000,
    costPrice: 2000,
  );
  final snack = Product(
    id: 'p2',
    name: 'Singkong Goreng',
    price: 7000,
    category: 'Makanan',
    icon: Icons.lunch_dining,
    stock: 1000,
    costPrice: 3500,
  );
  final store = AppStore(products: [drink, snack]);

  store.recordOrder(
    Order(
      id: 'o1',
      createdAt: day5,
      items: [CartItem(product: drink, quantity: 2)],
      paidAmount: 10000,
    ),
  );
  store.recordOrder(
    Order(
      id: 'o2',
      createdAt: day20,
      items: [
        CartItem(product: drink, quantity: 1),
        CartItem(product: snack, quantity: 1),
      ],
      paidAmount: 15000,
    ),
  );
  return store;
}