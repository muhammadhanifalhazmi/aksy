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

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] as String,
      amount: json['amount'] as int,
      at: DateTime.parse(json['at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'at': at.toIso8601String(),
    };
  }

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

  factory Debt.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type'] as String? ?? DebtType.receivable.name;
    return Debt(
      id: json['id'] as String,
      type: DebtType.values.asNameMap()[typeValue] ?? DebtType.receivable,
      partyName: json['partyName'] as String,
      amount: json['amount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.tryParse(json['dueDate'] as String),
      note: json['note'] as String?,
      paidAmount: json['paidAmount'] as int? ?? 0,
      payments: (json['payments'] as List<dynamic>? ?? const [])
          .map((e) => DebtPayment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'partyName': partyName,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'note': note,
      'paidAmount': paidAmount,
      'payments': payments.map((p) => p.toJson()).toList(),
    };
  }

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