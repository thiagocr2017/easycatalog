import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:easycatalog/data/database_helper.dart';

class ImageManager {
  static final ImageManager _instance = ImageManager._internal();
  factory ImageManager() => _instance;
  ImageManager._internal();

  final _dbHelper = DatabaseHelper.instance;

  /// 🔹 Comprime/redimensiona una imagen usando la librería 'image' (funciona en macOS/Windows/Linux)
  Future<File?> compressImage(File file, {int quality = 70, int maxSize = 1024}) async {
    try {
      debugPrint('🧩 Leyendo archivo: ${file.path}');
      final bytes = await file.readAsBytes();
      debugPrint('📦 Tamaño original (bytes): ${bytes.length}');

      final image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('❌ No se pudo decodificar la imagen.');
        return null;
      }

      // 🔹 Redimensionar proporcionalmente según el lado mayor
      final resized = img.copyResize(
        image,
        width: image.width > image.height ? maxSize : null,
        height: image.height >= image.width ? maxSize : null,
        interpolation: img.Interpolation.average,
      );

      // 🔹 Codificar como JPEG
      final compressedBytes = img.encodeJpg(resized, quality: quality);

      // 🔹 Guardar en carpeta temporal
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      final compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(compressedBytes);

      debugPrint('✅ Imagen comprimida en: $targetPath');
      return compressedFile;
    } catch (e) {
      debugPrint('❌ Error al comprimir imagen: $e');
      return null;
    }
  }

  /// 🔹 Limpia imágenes que ya no están en la base de datos
  Future<void> cleanOldImages() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final imagesDir = Directory('${appDir.path}/images');

      // ✅ Crear carpeta si no existe
      if (!imagesDir.existsSync()) {
        await imagesDir.create(recursive: true);
        debugPrint('📂 Carpeta creada: ${imagesDir.path}');
        return;
      }

      final usedPaths = await getUsedImagePathsFromDB();
      final usedNames = usedPaths.map((p) => p.split(Platform.pathSeparator).last).toSet();
      final allFiles = imagesDir.listSync(recursive: true).whereType<File>();

      int deletedCount = 0;
      for (final file in allFiles) {
        final name = file.uri.pathSegments.last;
        if (!usedNames.contains(name)) {
          debugPrint('🧹 (Saltado) $name no se encuentra en base — revisa manualmente.');
          // ⚠️ En vez de borrar directamente, mejor lo renombramos temporalmente.
          // await file.delete();
        }
      }

      debugPrint('🧼 Limpieza finalizada. Total eliminadas: $deletedCount');
    } catch (e) {
      debugPrint('❌ Error al limpiar imágenes: $e');
    }
  }

  /// 🔹 Obtiene todas las rutas de imágenes usadas en la base de datos
  Future<Set<String>> getUsedImagePathsFromDB() async {
    final db = await _dbHelper.database;
    final result = await db.query('products', columns: ['imagePath']);
    final paths = <String>{};

    for (final row in result) {
      final path = row['imagePath'] as String?;
      if (path != null && path.isNotEmpty) {
        paths.add(path);
      }
    }

    debugPrint('📂 ${paths.length} rutas de imágenes activas obtenidas de la base.');
    return paths;
  }

  /// 🔹 Optimiza todas las imágenes del catálogo (comprime y reemplaza si se reduce el tamaño)
  Future<void> optimizeAllImages({int quality = 70, int maxSize = 1024}) async {
    debugPrint('🚀 Iniciando optimización de imágenes...');
    final products = await _dbHelper.getProducts();
    debugPrint('🧩 Productos encontrados: ${products.length}');

    if (products.isEmpty) {
      debugPrint('⚠️ No hay productos para optimizar.');
      return;
    }

    // 📂 Usar la misma carpeta que el botón "Abrir carpeta"
    final appDir = await getApplicationSupportDirectory();
    final imagesDir = Directory('${appDir.path}/images');
    if (!imagesDir.existsSync()) {
      debugPrint('⚠️ Carpeta de imágenes no existe en: ${imagesDir.path}');
      return;
    }

    int optimizedCount = 0;

    for (final product in products) {
      final imageName = product['imagePath'] as String?;
      if (imageName == null || imageName.isEmpty) continue;

      final fullPath = '${imagesDir.path}/$imageName';
      final original = File(fullPath);

      if (!original.existsSync()) {
        debugPrint('⚠️ Archivo no encontrado: $fullPath');
        continue;
      }

      final before = original.lengthSync();
      final compressed = await compressImage(original, quality: quality, maxSize: maxSize);
      if (compressed == null) {
        debugPrint('❌ No se pudo generar versión comprimida de: $fullPath');
        continue;
      }

      final after = compressed.lengthSync();
      debugPrint('📊 $fullPath');
      debugPrint('Antes: ${(before / 1024).toStringAsFixed(1)} KB');
      debugPrint('Después: ${(after / 1024).toStringAsFixed(1)} KB');

      if (after < before) {
        await compressed.copy(original.path);
        optimizedCount++;
        debugPrint('✅ Imagen optimizada y reemplazada ($optimizedCount total).');
      } else {
        debugPrint('⚠️ No hubo mejora, se mantiene original.');
      }
    }

    debugPrint('🏁 Optimización finalizada. Total optimizadas: $optimizedCount');
  }

  Future<void> optimizeAllImagesWithCallback({
    required Function(String) onLog,
    int quality = 70,
    int maxSize = 1024,
  }) async {
    onLog('🚀 Iniciando optimización de imágenes...');
    final products = await _dbHelper.getProducts();
    onLog('🧩 Productos encontrados: ${products.length}');

    if (products.isEmpty) {
      onLog('⚠️ No hay productos para optimizar.');
      return;
    }

    final appDir = await getApplicationSupportDirectory();
    final imagesDir = Directory('${appDir.path}/images');
    if (!imagesDir.existsSync()) {
      await imagesDir.create(recursive: true);
      onLog('📂 Carpeta creada: ${imagesDir.path}');
    }

    int optimizedCount = 0;

    for (final product in products) {
      final imageName = product['imagePath'] as String?;
      if (imageName == null || imageName.isEmpty) continue;

      final fullPath = '${imagesDir.path}/$imageName';
      final original = File(fullPath);

      if (!original.existsSync()) {
        onLog('⚠️ Archivo no encontrado: $imageName');
        continue;
      }

      final before = original.lengthSync();
      final compressed = await compressImage(original, quality: quality, maxSize: maxSize);
      if (compressed == null) {
        onLog('❌ Error al comprimir: $imageName');
        continue;
      }

      final after = compressed.lengthSync();
      if (after < before) {
        await compressed.copy(original.path);
        optimizedCount++;
        onLog('✅ $imageName optimizada (${(before / 1024).toStringAsFixed(1)} KB → ${(after / 1024).toStringAsFixed(1)} KB)');
      } else {
        onLog('⚠️ $imageName sin mejora (${(before / 1024).toStringAsFixed(1)} KB)');
      }
    }

    onLog('🏁 Optimización finalizada. Total optimizadas: $optimizedCount');
  }

}
