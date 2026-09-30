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
    this.source = CashEntrySource.manual,
    this.debtId,
  });

  factory CashEntry.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type'] as String? ?? CashFlowType.cashIn.name;
    final category = json['category'] as String;
    final sourceName = json['source'] as String?;
    return CashEntry(
      id: json['id'] as String,
      type: CashFlowType.values.asNameMap()[typeValue] ?? CashFlowType.cashIn,
      amount: json['amount'] as int,
      category: category,
      createdAt: DateTime.parse(json['createdAt'] as String),
      note: json['note'] as String?,
      source: sourceName == null
          ? _inferSource(category)
          : CashEntrySource.values.asNameMap()[sourceName] ??
                CashEntrySource.manual,
      debtId: json['debtId'] as String?,
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
      'source': source.name,
      'debtId': debtId,
    };
  }

  static CashEntrySource _inferSource(String category) {
    if (category == 'Penjualan') return CashEntrySource.sale;
    if (category == 'Pembayaran Piutang' || category == 'Pembayaran Hutang') {
      return CashEntrySource.debtPayment;
    }
    return CashEntrySource.manual;
  }

  final String id;
  final CashFlowType type;
  final int amount;
  final String category;
  final DateTime createdAt;
  final String? note;
  final CashEntrySource source;
  final String? debtId;

  /// Catatan yang dibuat otomatis oleh penjualan atau pembayaran utang
  /// tidak boleh diubah manual, jika tidak pembukuan kas dan utang jadi
  /// tidak sinkron.
  bool get isEditable => source == CashEntrySource.manual;

  CashEntry copyWith({
    CashFlowType? type,
    int? amount,
    String? category,
    String? note,
  }) {
    return CashEntry(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      createdAt: createdAt,
      note: note ?? this.note,
      source: source,
      debtId: debtId,
    );
  }
}

enum CashEntrySource { manual, sale, debtPayment }

extension CashEntrySourceLabel on CashEntrySource {
  String? get lockedReason {
    switch (this) {
      case CashEntrySource.manual:
        return null;
      case CashEntrySource.sale:
        return 'Catatan ini dibuat otomatis dari penjualan, jadi tidak bisa diubah atau dihapus.';
      case CashEntrySource.debtPayment:
        return 'Catatan ini dibuat otomatis dari pembayaran utang/piutang, jadi tidak bisa diubah atau dihapus.';
    }
  }

  String get label {
    switch (this) {
      case CashEntrySource.manual:
        return 'Manual';
      case CashEntrySource.sale:
        return 'Otomatis';
      case CashEntrySource.debtPayment:
        return 'Otomatis';
    }
  }
}