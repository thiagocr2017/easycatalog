class StyleSettings {
  final int backgroundColor;
  final int highlightColor;
  final int infoBoxColor;
  final int textColor;
  final String? logoPath;

  const StyleSettings({
    required this.backgroundColor,
    required this.highlightColor,
    required this.infoBoxColor,
    required this.textColor,
    this.logoPath,
  });

  // 🎨 Colores por defecto actualizados
  factory StyleSettings.defaults() => const StyleSettings(
    backgroundColor: 0xFFE1F6B4, // Fondo: #FFE1F6B4
    highlightColor: 0xFF50B203,  // Destacado: #FF50B203
    infoBoxColor: 0xFFEEE9CC,    // Caja de información: #FFEEE9CC
    textColor: 0xFF222222,       // Texto: #FF222222
  );

  Map<String, Object?> toMap() => {
    'backgroundColor': backgroundColor,
    'highlightColor': highlightColor,
    'infoBoxColor': infoBoxColor,
    'textColor': textColor,
    'logoPath': logoPath,
  };

  factory StyleSettings.fromMap(Map<String, Object?> map) => StyleSettings(
    backgroundColor: (map['backgroundColor'] as int?) ?? 0xFFF4F7F8,
    highlightColor: (map['highlightColor'] as int?) ?? 0xFF3A8FB7,
    infoBoxColor: (map['infoBoxColor'] as int?) ?? 0xFFE6E1C5,
    textColor: (map['textColor'] as int?) ?? 0xFF222222,
    logoPath: map['logoPath'] as String?,
  );

  StyleSettings copyWith({
    int? backgroundColor,
    int? highlightColor,
    int? infoBoxColor,
    int? textColor,
    String? logoPath,
  }) {
    return StyleSettings(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      highlightColor: highlightColor ?? this.highlightColor,
      infoBoxColor: infoBoxColor ?? this.infoBoxColor,
      textColor: textColor ?? this.textColor,
      logoPath: logoPath ?? this.logoPath,
    );
  }
}
