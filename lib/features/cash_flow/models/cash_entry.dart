enum CashFlowType { cashIn, cashOut }

extension CashFlowTypeLabel on CashFlowType {
  String get label {
    switch (this) {
      case CashFlowType.cashIn:
        return 'Kas Masuk';
      case CashFlowType.cashOut:
        return 'Kas Keluar';
    }
  }
}

class CashEntry {
  const CashEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.createdAt,
    this.note,
  });

  final String id;
  final CashFlowType type;
  final int amount;
  final String category;
  final DateTime createdAt;
  final String? note;
}