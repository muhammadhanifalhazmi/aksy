class StoreSettings {
  const StoreSettings({
    this.name = 'Aplikasi Kasir Easy',
    this.address = '',
    this.phone = '',
    this.footer = '',
  });

  factory StoreSettings.fromJson(Map<String, dynamic> json) {
    return StoreSettings(
      name: json['name'] as String? ?? 'Aplikasi Kasir Easy',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      footer: json['footer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'footer': footer,
    };
  }

  final String name;
  final String address;
  final String phone;
  final String footer;

  StoreSettings copyWith({
    String? name,
    String? address,
    String? phone,
    String? footer,
  }) {
    return StoreSettings(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      footer: footer ?? this.footer,
    );
  }
}