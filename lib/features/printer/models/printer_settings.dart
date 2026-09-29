class PrinterSettings {
  const PrinterSettings({
    this.deviceAddress = '',
    this.deviceName = '',
    this.wide = false,
    this.autoPrint = false,
    this.copies = 1,
    this.cut = true,
  });

  factory PrinterSettings.fromJson(Map<String, dynamic> json) {
    return PrinterSettings(
      deviceAddress: json['deviceAddress'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      wide: json['wide'] as bool? ?? false,
      autoPrint: json['autoPrint'] as bool? ?? false,
      copies: json['copies'] as int? ?? 1,
      cut: json['cut'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceAddress': deviceAddress,
      'deviceName': deviceName,
      'wide': wide,
      'autoPrint': autoPrint,
      'copies': copies,
      'cut': cut,
    };
  }

  final String deviceAddress;
  final String deviceName;
  final bool wide;
  final bool autoPrint;
  final int copies;
  final bool cut;

  bool get isConfigured => deviceAddress.isNotEmpty;

  PrinterSettings copyWith({
    String? deviceAddress,
    String? deviceName,
    bool? wide,
    bool? autoPrint,
    int? copies,
    bool? cut,
  }) {
    return PrinterSettings(
      deviceAddress: deviceAddress ?? this.deviceAddress,
      deviceName: deviceName ?? this.deviceName,
      wide: wide ?? this.wide,
      autoPrint: autoPrint ?? this.autoPrint,
      copies: copies ?? this.copies,
      cut: cut ?? this.cut,
    );
  }
}
