class ShiftRecord {
  const ShiftRecord({
    required this.id,
    required this.openTime,
    required this.startingCash,
    this.expectedCash,
    this.actualCash,
    this.note,
    this.closeTime,
  });

  factory ShiftRecord.fromJson(Map<String, dynamic> json) {
    return ShiftRecord(
      id: json['id'] as String,
      openTime: DateTime.parse(json['openTime'] as String),
      startingCash: json['startingCash'] as int,
      expectedCash: json['expectedCash'] as int?,
      actualCash: json['actualCash'] as int?,
      note: json['note'] as String?,
      closeTime: json['closeTime'] == null
          ? null
          : DateTime.tryParse(json['closeTime'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'openTime': openTime.toIso8601String(),
      'startingCash': startingCash,
      'expectedCash': expectedCash,
      'actualCash': actualCash,
      'note': note,
      'closeTime': closeTime?.toIso8601String(),
    };
  }

  final String id;
  final DateTime openTime;
  final int startingCash;
  final int? expectedCash;
  final int? actualCash;
  final String? note;
  final DateTime? closeTime;

  bool get isOpen => closeTime == null;

  int? get difference {
    if (expectedCash == null || actualCash == null) return null;
    return actualCash! - expectedCash!;
  }
}