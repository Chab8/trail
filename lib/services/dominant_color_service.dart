import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

/// Extrae el color dominante de una imagen.
///
/// El algoritmo está basado en el algoritmo `dominant`
/// de Fast Average Color:
/// https://github.com/fast-average-color/fast-average-color
///
/// Fast Average Color agrupa los colores RGB en buckets y
/// selecciona el bucket con mayor frecuencia.
///
/// Para Trail utilizamos una imagen reducida antes de analizarla.
/// Esto hace que el proceso sea muy rápido incluso con portadas
/// de Spotify de alta resolución.
class DominantColorService {
  DominantColorService._();

  static const int _dominantDivider = 24;

  /// Cacheamos el resultado por URL.
  ///
  /// Esto es importante porque NowPlayingBar consulta Spotify
  /// periódicamente. Si la canción no cambió, no queremos
  /// descargar ni analizar la imagen nuevamente.
  static final Map<String, ui.Color> _cache = {};

  /// Devuelve el color dominante de una imagen remota.
  ///
  /// [imageUrl] debe ser una URL accesible.
  ///
  /// Si ocurre cualquier error, devuelve null.
  static Future<ui.Color?> getColor(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    // 1. Buscar primero en cache.
    final cachedColor = _cache[imageUrl];

    if (cachedColor != null) {
      return cachedColor;
    }

    try {
      // 2. Descargar la imagen.
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      // 3. Decodificar la imagen y reducirla.
      //
      // 64 px es más que suficiente para detectar el color
      // dominante de una portada musical.
      final codec = await ui.instantiateImageCodec(
        response.bodyBytes,
        targetWidth: 64,
      );

      final frame = await codec.getNextFrame();
      final image = frame.image;

      // 4. Obtener los pixels RGBA.
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) {
        image.dispose();
        codec.dispose();
        return null;
      }

      final pixels = byteData.buffer.asUint8List();

      // 5. Ejecutar el algoritmo dominante.
      final color = _getDominantColor(
        pixels,
        divider: _dominantDivider,
      );

      // Liberamos los recursos nativos.
      image.dispose();
      codec.dispose();

      if (color != null) {
        _cache[imageUrl] = color;
      }

      return color;
    } catch (_) {
      return null;
    }
  }

  /// Implementación Dart del algoritmo `dominant`
  /// de Fast Average Color.
  ///
  /// La librería original:
  ///
  /// - toma RGB + Alpha
  /// - agrupa colores mediante un divider
  /// - cuenta la frecuencia de cada bucket
  /// - calcula el promedio RGB del bucket ganador
  ///
  /// Ver:
  /// https://github.com/fast-average-color/fast-average-color
  static ui.Color? _getDominantColor(
    Uint8List pixels, {
    required int divider,
  }) {
    if (pixels.length < 4) {
      return null;
    }

    // key -> [redTotal, greenTotal, blueTotal, alphaTotal, count]
    final Map<String, List<double>> colorBuckets = {};

    List<double>? dominantBucket;

    int maxCount = 0;

    // Cada pixel ocupa 4 bytes:
    //
    // [R, G, B, A]
    for (int i = 0; i + 3 < pixels.length; i += 4) {
      final int red = pixels[i];
      final int green = pixels[i + 1];
      final int blue = pixels[i + 2];
      final int alpha = pixels[i + 3];

      // Ignoramos pixels completamente transparentes.
      if (alpha == 0) {
        continue;
      }

      // Igual que Fast Average Color:
      //
      // Math.round(red / divider)
      // Math.round(green / divider)
      // Math.round(blue / divider)
      final int redBucket = _round(red / divider);
      final int greenBucket = _round(green / divider);
      final int blueBucket = _round(blue / divider);

      final String key =
          '$redBucket,$greenBucket,$blueBucket';

      final bucket = colorBuckets.putIfAbsent(
        key,
        () => <double>[0, 0, 0, 0, 0],
      );

      // Weighted by alpha, igual que el algoritmo original.
      bucket[0] += red * alpha;
      bucket[1] += green * alpha;
      bucket[2] += blue * alpha;
      bucket[3] += alpha;
      bucket[4] += 1;

      final int count = bucket[4].toInt();

      if (count > maxCount) {
        maxCount = count;
        dominantBucket = bucket;
      }
    }

    if (dominantBucket == null || dominantBucket[3] == 0) {
      return null;
    }

    final double redTotal = dominantBucket[0];
    final double greenTotal = dominantBucket[1];
    final double blueTotal = dominantBucket[2];
    final double alphaTotal = dominantBucket[3];
    final double count = dominantBucket[4];

    final int red = _clamp(
      (redTotal / alphaTotal).round(),
    );

    final int green = _clamp(
      (greenTotal / alphaTotal).round(),
    );

    final int blue = _clamp(
      (blueTotal / alphaTotal).round(),
    );

    final int alpha = _clamp(
      (alphaTotal / count).round(),
    );

    return ui.Color.fromARGB(
      alpha,
      red,
      green,
      blue,
    );
  }

  static int _round(double value) {
    return value.round();
  }

  static int _clamp(int value) {
    if (value < 0) return 0;
    if (value > 255) return 255;
    return value;
  }

  /// Permite limpiar la cache si alguna vez queremos hacerlo
  /// explícitamente.
  static void clearCache() {
    _cache.clear();
  }

  /// Elimina únicamente una imagen de la cache.
  static void removeFromCache(String imageUrl) {
    _cache.remove(imageUrl);
  }
}