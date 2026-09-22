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