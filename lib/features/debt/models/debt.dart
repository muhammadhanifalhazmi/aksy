enum DebtType { receivable, payable }

extension DebtTypeLabel on DebtType {
  String get label {
    switch (this) {
      case DebtType.receivable:
        return 'Piutang';
      case DebtType.payable:
        return 'Hutang';
    }
  }
}

class DebtPayment {
  const DebtPayment({required this.id, required this.amount, required this.at});

  final String id;
  final int amount;
  final DateTime at;
}

class Debt {
  const Debt({
    required this.id,
    required this.type,
    required this.partyName,
    required this.amount,
    required this.createdAt,
    this.dueDate,
    this.note,
    this.paidAmount = 0,
    this.payments = const [],
  });

  final String id;
  final DebtType type;
  final String partyName;
  final int amount;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String? note;
  final int paidAmount;
  final List<DebtPayment> payments;

  bool get isPaid => paidAmount >= amount;

  int get remaining {
    final value = amount - paidAmount;
    return value < 0 ? 0 : value;
  }

  bool get isOverdue {
    if (isPaid || dueDate == null) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  Debt copyWith({int? paidAmount, List<DebtPayment>? payments}) {
    return Debt(
      id: id,
      type: type,
      partyName: partyName,
      amount: amount,
      createdAt: createdAt,
      dueDate: dueDate,
      note: note,
      paidAmount: paidAmount ?? this.paidAmount,
      payments: payments ?? this.payments,
    );
  }
}