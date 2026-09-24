import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';

enum ReportPeriodType {
  daily('Harian', Icons.calendar_today_outlined),
  weekly('Mingguan', Icons.calendar_view_week_outlined),
  monthly('Bulanan', Icons.calendar_month_outlined),
  quarterly('Kuartal', Icons.view_module_outlined),
  yearly('Tahunan', Icons.event_outlined);

  const ReportPeriodType(this.label, this.icon);

  final String label;
  final IconData icon;
}

class ReportPeriod {
  ReportPeriod({required this.type, required this.anchor});

  final ReportPeriodType type;
  final DateTime anchor;

  DateTime get start {
    final a = DateTime(anchor.year, anchor.month, anchor.day);
    switch (type) {
      case ReportPeriodType.daily:
        return a;
      case ReportPeriodType.weekly:
        return a.subtract(Duration(days: a.weekday - 1));
      case ReportPeriodType.monthly:
        return DateTime(a.year, a.month, 1);
      case ReportPeriodType.quarterly:
        final firstMonth = (a.month - 1) ~/ 3 * 3 + 1;
        return DateTime(a.year, firstMonth, 1);
      case ReportPeriodType.yearly:
        return DateTime(a.year, 1, 1);
    }
  }

  DateTime get endExclusive {
    switch (type) {
      case ReportPeriodType.daily:
        return DateTime(anchor.year, anchor.month, anchor.day + 1);
      case ReportPeriodType.weekly:
        return DateTime(start.year, start.month, start.day + 7);
      case ReportPeriodType.monthly:
        return DateTime(start.year, start.month + 1, 1);
      case ReportPeriodType.quarterly:
        return DateTime(start.year, start.month + 3, 1);
      case ReportPeriodType.yearly:
        return DateTime(start.year + 1, 1, 1);
    }
  }

  DateTime get end => endExclusive.subtract(const Duration(days: 1));

  String get title => 'Laporan ${type.label.toLowerCase()}';

  String get rangeLabel {
    final s = start;
    final e = end;
    const months = DateFormatter.months;
    if (s.year == e.year) {
      final sMonth = '${s.day} ${months[s.month - 1]}';
      final eMonth = '${e.day} ${months[e.month - 1]}';
      if (s.month == e.month) {
        return '${s.day} - $eMonth ${e.year}';
      }
      return '$sMonth - $eMonth ${e.year}';
    }
    return '${DateFormatter.reportDate(s)} - ${DateFormatter.reportDate(e)}';
  }

  String get fileName {
    final s = start;
    final month = s.month.toString().padLeft(2, '0');
    final day = s.day.toString().padLeft(2, '0');
    return 'laporan-${type.name}-$month-$day-${s.year}';
  }

  String get anchorLabel {
    switch (type) {
      case ReportPeriodType.daily:
      case ReportPeriodType.weekly:
        return DateFormatter.reportDate(anchor);
      case ReportPeriodType.monthly:
        return '${DateFormatter.months[anchor.month - 1]} ${anchor.year}';
      case ReportPeriodType.quarterly:
        final quarter = (anchor.month - 1) ~/ 3 + 1;
        return 'Q$quarter ${anchor.year}';
      case ReportPeriodType.yearly:
        return '${anchor.year}';
    }
  }

  IconData get icon => type.icon;
}