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

  factory CashEntry.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type'] as String? ?? CashFlowType.cashIn.name;
    return CashEntry(
      id: json['id'] as String,
      type: CashFlowType.values.asNameMap()[typeValue] ?? CashFlowType.cashIn,
      amount: json['amount'] as int,
      category: json['category'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
    };
  }

  final String id;
  final CashFlowType type;
  final int amount;
  final String category;
  final DateTime createdAt;
  final String? note;
}