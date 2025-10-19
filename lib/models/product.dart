class Product {
  final int? id;
  final String name;
  final String description;
  final double price;
  final String? imagePath;
  final int? sectionId;
  bool isDepleted; // puede cambiar dinámicamente
  final String createdAt;
  String? depletedAt;
  int sortOrder; // ✅ nuevo campo editable para drag & drop

  Product({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imagePath,
    this.sectionId,
    this.isDepleted = false,
    String? createdAt,
    this.depletedAt,
    this.sortOrder = 0, // valor por defecto
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'imagePath': imagePath,
    'sectionId': sectionId,
    'isDepleted': isDepleted ? 1 : 0,
    'createdAt': createdAt,
    'depletedAt': depletedAt,
    'sortOrder': sortOrder,
  };

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      imagePath: map['imagePath'] as String?,
      sectionId: map['sectionId'] as int?,
      isDepleted: (map['isDepleted'] ?? 0) == 1,
      createdAt: map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      depletedAt: map['depletedAt'] as String?,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }
}
