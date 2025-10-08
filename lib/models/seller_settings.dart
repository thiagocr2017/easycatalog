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
    name: 'Thiago Hernández',
    phone: '+52 55 1234 5678',
    message: 'Hola Thiago, me gustaría hacer un pedido.',
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
