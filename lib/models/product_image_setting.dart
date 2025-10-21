// 📄 lib/models/product_image_setting.dart

class ProductImageSetting {
  final int? id;
  final int productId;
  double zoom;
  double offsetX;
  double offsetY;

  ProductImageSetting({
    this.id,
    required this.productId,
    this.zoom = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'zoom': zoom,
      'offsetX': offsetX,
      'offsetY': offsetY,
    };
  }

  factory ProductImageSetting.fromMap(Map<String, dynamic> map) {
    return ProductImageSetting(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      zoom: (map['zoom'] as num?)?.toDouble() ?? 1.0,
      offsetX: (map['offsetX'] as num?)?.toDouble() ?? 0.0,
      offsetY: (map['offsetY'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ProductImageSetting copyWith({
    int? id,
    int? productId,
    double? zoom,
    double? offsetX,
    double? offsetY,
  }) {
    return ProductImageSetting(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      zoom: zoom ?? this.zoom,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
    );
  }
}