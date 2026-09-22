class DateFormatter {
  const DateFormatter._();

  static const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static String when(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)} ${months[date.month - 1]} ${date.year}, '
        '${two(date.hour)}:${two(date.minute)}';
  }

  static String reportDate(DateTime date) {
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String timeOnly(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)}';
  }
}