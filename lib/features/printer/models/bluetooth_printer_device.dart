class BluetoothPrinterDevice {
  const BluetoothPrinterDevice({required this.name, required this.address});

  final String name;
  final String address;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothPrinterDevice &&
          other.name == name &&
          other.address == address;

  @override
  int get hashCode => Object.hash(name, address);
}

class PrinterException implements Exception {
  const PrinterException(this.message);

  final String message;

  @override
  String toString() => message;
}
