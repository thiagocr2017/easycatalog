class SellerSettings {
  final String name;
  final String phone;
  final String message;

  const SellerSettings({
    required this.name,
    required this.phone,
    required this.message,
  });

  factory SellerSettings.defaults() => const SellerSettings(
    name: '',
    phone: '',
    message: '',
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'phone': phone,
    'message': message,
  };

  factory SellerSettings.fromMap(Map<String, Object?> map) => SellerSettings(
    name: (map['name'] ?? '') as String,
    phone: (map['phone'] ?? '') as String,
    message: (map['message'] ?? '') as String,
  );
}
