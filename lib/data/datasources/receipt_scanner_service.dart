import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:wallet_ai/data/datasources/groq_service.dart';
import '../database/daos/learning_rules_dao.dart';

class ReceiptItem {
  String name;
  double price;
  String? category;
  String? subcategory;
  double? quantity;
  String? unit;

  ReceiptItem({
    required this.name,
    required this.price,
    this.category,
    this.subcategory,
    this.quantity,
    this.unit,
  });
}

/// Resultado del escaneo de factura
class ScannedReceipt {
  final double? amount;
  final DateTime? date;
  final String? merchant;
  final String? productName; // Nombre del producto principal detectado
  final double? quantity;
  final String? unit;
  final String? category;
  final String? subcategory;
  final List<ReceiptItem>? items; // Para el escaneo múltiple
  final String? currency; // Siempre 'PEN' para boletas peruanas
  final String rawText;
  final String? imagePath; // Added for image preview
  final bool success;
  final String? errorMessage;

  /// Confianza de clasificación de la IA (0.0–1.0)
  final double? confidence;

  const ScannedReceipt({
    this.amount,
    this.date,
    this.merchant,
    this.productName,
    this.quantity,
    this.unit,
    this.category,
    this.subcategory,
    this.items,
    this.currency = 'PEN',
    required this.rawText,
    this.imagePath,
    this.success = true,
    this.errorMessage,
    this.confidence,
  });

  factory ScannedReceipt.error(String message) => ScannedReceipt(
    rawText: '',
    imagePath: null,
    success: false,
    errorMessage: message,
  );

  @override
  String toString() =>
      'ScannedReceipt(amount: $amount, merchant: $merchant, productName: $productName, confidence: ${confidence?.toStringAsFixed(2)})';
}

/// Servicio avanzado de escaneo de facturas con MLKit OCR.
/// Extrae: monto total, fecha de emisión, nombre del comercio,
/// nombre del producto y texto raw.
class ReceiptScannerService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  // ─── Captura de imagen ────────────────────────────────────────────────────

  /// Abre la cámara y escanea la factura
  Future<ScannedReceipt?> scanFromCamera({
    bool isMultiple = false,
    LearningRulesDao? dao,
  }) => _scan(ImageSource.camera, isMultiple: isMultiple, dao: dao);

  /// Abre la galería y escanea la imagen seleccionada
  Future<ScannedReceipt?> scanFromGallery({
    bool isMultiple = false,
    LearningRulesDao? dao,
  }) => _scan(ImageSource.gallery, isMultiple: isMultiple, dao: dao);

  Future<ScannedReceipt?> _scan(
    ImageSource source, {
    bool isMultiple = false,
    LearningRulesDao? dao,
  }) async {
    // Importación dentro del scope para usar el servicio de Groq
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image == null) return null;

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      if (recognizedText.text.isEmpty) {
        return ScannedReceipt.error(
          'No se pudo leer texto en la imagen.\nIntenta con mejor iluminación o una foto más nítida.',
        );
      }

      return _processTextWithGroq(recognizedText, isMultiple, image.path, dao);
    } catch (e) {
      debugPrint('ReceiptScannerService error: $e');
      return ScannedReceipt.error('Error al procesar la imagen: $e');
    }
  }

  // ─── Parsing ──────────────────────────────────────────────────────────────

  Future<ScannedReceipt> _processTextWithGroq(
    RecognizedText recognizedText,
    bool isMultiple,
    String imagePath,
    LearningRulesDao? dao,
  ) async {
    final String raw = recognizedText.text;

    final groq = GroqService();
    final data = await groq.parseReceipt(raw, isMultiple: isMultiple);

    if (data != null) {
      // Parse amount safely
      double? amount;
      if (data['total_boleta'] != null) {
        amount = double.tryParse(data['total_boleta'].toString());
      }

      // Parse date safely
      DateTime? date;
      if (data['fecha'] != null) {
        date = DateTime.tryParse(data['fecha'].toString());
      }

      String? productName;
      String? category;
      String? subcategory;
      double? quantity;
      String? unit;
      List<ReceiptItem>? items;

      if (isMultiple &&
          data['productos'] != null &&
          data['productos'] is List) {
        items = (data['productos'] as List).map((p) {
          return ReceiptItem(
            name: p['nombre_producto']?.toString() ?? 'Producto',
            price:
                double.tryParse(p['importe_total']?.toString() ?? '0') ?? 0.0,
            category: p['categoria']?.toString(),
            subcategory: p['subcategoria']?.toString(),
            quantity: double.tryParse(p['cantidad']?.toString() ?? '1'),
            unit: p['unidad']?.toString(),
          );
        }).toList();

        // 🧠 APRENDIZAJE PERSISTENTE: Sobrescribir con reglas locales si existen
        if (dao != null) {
          for (var item in items) {
            final rule = await dao.getRuleForProduct(item.name);
            if (rule != null && rule.usageCount >= 1) {
              // Sobrescritura directa
              item.category = rule.categoryId;
              debugPrint(
                '🧠 AI Interceptada: Cambiando categoría de ${item.name} a ${rule.categoryId}',
              );
            }
          }
        }
      } else {
        if (data['productos'] != null &&
            data['productos'] is List &&
            (data['productos'] as List).isNotEmpty) {
          productName = data['productos'][0]['nombre_producto']?.toString();
          category = data['productos'][0]['categoria']?.toString();
          subcategory = data['productos'][0]['subcategoria']?.toString();
          quantity = double.tryParse(
            data['productos'][0]['cantidad']?.toString() ?? '1',
          );
          unit = data['productos'][0]['unidad']?.toString();

          // 🧠 APRENDIZAJE PERSISTENTE
          if (dao != null && productName != null) {
            final rule = await dao.getRuleForProduct(productName);
            if (rule != null && rule.usageCount >= 1) {
              category = rule.categoryId;
              debugPrint(
                '🧠 AI Interceptada: Cambiando categoría de $productName a ${rule.categoryId}',
              );
            }
          }
        }
      }

      return ScannedReceipt(
        amount: amount ?? _extractBestAmount(raw),
        date: date ?? _extractDate(raw),
        merchant:
            data['comercio']?.toString() ?? _extractMerchant(recognizedText),
        productName: productName ?? _extractProductName(raw),
        quantity: quantity,
        unit: unit,
        category: category,
        subcategory: subcategory,
        items: items,
        rawText: raw,
        imagePath: imagePath,
        confidence: double.tryParse(
          data['confianza_clasificacion']?.toString() ?? '',
        ),
      );
    }

    // Si Groq falla o devuelve null, usamos el fallback Regex
    return _parseReceiptFallback(
      recognizedText,
      isMultiple: isMultiple,
      imagePath: imagePath,
    );
  }

  ScannedReceipt _parseReceiptFallback(
    RecognizedText recognizedText, {
    bool isMultiple = false,
    String? imagePath,
  }) {
    final String recognizedTextStr = recognizedText.text;

    final merchant = _extractMerchant(recognizedText);
    final date = _extractDate(recognizedTextStr);
    final amount = _extractBestAmount(recognizedTextStr);

    String? productName;
    List<ReceiptItem>? items;

    if (isMultiple) {
      items = _extractMultipleItems(recognizedTextStr);
    } else {
      productName = _extractProductName(recognizedTextStr);
    }

    return ScannedReceipt(
      amount: amount,
      date: date,
      merchant: merchant,
      productName: productName,
      items: items,
      rawText: recognizedTextStr,
      imagePath: imagePath, // Siempre preservado
    );
  }

  // ─── Extracción de monto ──────────────────────────────────────────────────

  /// Extrae el monto total de la factura con prioridad estricta:
  /// 1. "Importe Total" / "Total a pagar" (prioridad máxima)
  /// 2. "Total" sin calificadores (prioridad media)
  /// 3. Mayor monto con decimales en últimas 15 líneas (fallback)
  /// NOTA: "subtotal" NO se usa como keyword de total — puede ser previo a descuentos.
  /// NOTA: Líneas de puntos/fidelidad (ej: "Puntos » 230 S/2.30") son ignoradas.
  double? _extractBestAmount(String text) {
    final lines = text.split('\n');
    final amountPattern = RegExp(r'(\d{1,7}[.,]\d{2})');

    // Prioridad 1: Líneas que contienen "importe total" o "total a pagar"
    const highPriorityKeywords = [
      'importe total',
      'total a pagar',
      'monto total',
      'total general',
      'total cobrado',
      'valor total',
      'grand total',
      'amount due',
    ];

    // Prioridad 2: Líneas que contienen solo "total" (pero NO "subtotal" ni "puntos")
    const mediumPriorityKeywords = ['total'];

    // Líneas a IGNORAR aunque contengan "total"
    const ignorePatterns = [
      'subtotal',
      'puntos',
      'acumulado',
      'fidelidad',
      'descuento',
      'igv',
      'tax',
    ];

    double? highPriorityAmount;
    double? mediumPriorityAmount;

    for (final line in lines) {
      final lower = line.toLowerCase().trim();

      // Verificar si la línea debe ignorarse
      if (ignorePatterns.any((p) => lower.contains(p))) continue;

      final matches = amountPattern.allMatches(line);
      if (matches.isEmpty) continue;

      // Extraer el mayor monto de la línea
      double? lineMax;
      for (final m in matches) {
        final val = _parseAmountStr(m.group(1)!);
        if (val != null && val > 0) {
          if (lineMax == null || val > lineMax) lineMax = val;
        }
      }
      if (lineMax == null) continue;

      // Asignar según prioridad
      if (highPriorityKeywords.any((kw) => lower.contains(kw))) {
        if (highPriorityAmount == null || lineMax > highPriorityAmount) {
          highPriorityAmount = lineMax;
        }
      } else if (mediumPriorityKeywords.any(
        (kw) =>
            lower == kw || lower.startsWith('$kw ') || lower.endsWith(' $kw'),
      )) {
        if (mediumPriorityAmount == null || lineMax > mediumPriorityAmount) {
          mediumPriorityAmount = lineMax;
        }
      }
    }

    if (highPriorityAmount != null) return highPriorityAmount;
    if (mediumPriorityAmount != null) return mediumPriorityAmount;

    // Fallback: el mayor número con decimales de las últimas 15 líneas
    // (excluyendo líneas de puntos/fidelidad)
    final lastLines = lines.length > 15
        ? lines.sublist(lines.length - 15)
        : lines;
    double? largest;
    for (final line in lastLines) {
      final lower = line.toLowerCase();
      if (ignorePatterns.any((p) => lower.contains(p))) continue;
      for (final m in amountPattern.allMatches(line)) {
        final val = _parseAmountStr(m.group(1)!);
        if (val != null && val >= 1.0) {
          if (largest == null || val > largest) largest = val;
        }
      }
    }
    return largest;
  }

  double? _parseAmountStr(String raw) =>
      double.tryParse(raw.replaceAll(',', '.'));

  // ─── Extracción de fecha ──────────────────────────────────────────────────

  DateTime? _extractDate(String text) {
    // Palabras clave de fecha en boletas peruanas (buscar fecha de emisión preferentemente)
    final lines = text.split('\n');

    // Primero buscar líneas con keywords de fecha principal
    const dateKeywords = [
      'fecha',
      'emision',
      'emisión',
      'f.pago',
      'fpago',
      'fecha de',
    ];
    final numericDate = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b');

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (dateKeywords.any((kw) => lower.contains(kw))) {
        final m = numericDate.firstMatch(line);
        if (m != null) {
          final d = _tryParseDate(m.group(1)!, m.group(2)!, m.group(3)!);
          if (d != null) return d;
        }
      }
    }

    // Fallback: primera fecha numérica encontrada
    final numMatch = numericDate.firstMatch(text);
    if (numMatch != null) {
      return _tryParseDate(
        numMatch.group(1)!,
        numMatch.group(2)!,
        numMatch.group(3)!,
      );
    }

    // Textual: "14 FEB 2026" o "FEB 14 2026" o "FEBR 14 2026"
    const months = {
      'ENE': 1,
      'FEB': 2,
      'FEBR': 2,
      'MAR': 3,
      'ABR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AGO': 8,
      'SEP': 9,
      'SET': 9,
      'OCT': 10,
      'NOV': 11,
      'DIC': 12,
      'JAN': 1,
      'APR': 4,
      'AUG': 8,
      'DEC': 12,
    };

    final textDate = RegExp(
      r'\b([A-Z]{3,4})\s+(\d{1,2})\s+(\d{4})\b|\b(\d{1,2})\s+([A-Z]{3,4})\s+(\d{4})\b',
      caseSensitive: false,
    );
    final tMatch = textDate.firstMatch(text.toUpperCase());
    if (tMatch != null) {
      try {
        final monthStr = (tMatch.group(1) ?? tMatch.group(5))!;
        final day = int.parse(tMatch.group(2) ?? tMatch.group(4)!);
        final year = int.parse(tMatch.group(3) ?? tMatch.group(6)!);
        final month = months[monthStr];
        if (month != null) return DateTime(year, month, day);
      } catch (_) {}
    }

    return null;
  }

  DateTime? _tryParseDate(String a, String b, String c) {
    try {
      int x = int.parse(a);
      int y = int.parse(b);
      int z = int.parse(c);
      int year = z < 100 ? z + 2000 : z;
      if (x > 31) return DateTime(x, y, z); // YYYY-MM-DD
      return DateTime(year, y, x); // DD/MM/YYYY
    } catch (_) {
      return null;
    }
  }

  // ─── Extracción de comercio ───────────────────────────────────────────────

  /// Detecta el nombre del comercio (primeras líneas destacadas).
  String? _extractMerchant(RecognizedText recognizedText) {
    final ignoredPatterns = RegExp(
      r'^\d|RUC|NIT|RFC|www\.|http|@|BOLETA|FACTURA|TICKET|comprobante|BOLETA|JR\.|AV\.|URB\.',
      caseSensitive: false,
    );

    for (final block in recognizedText.blocks.take(3)) {
      final firstLine = block.text.trim().split('\n').first.trim();
      if (firstLine.length >= 4 && !ignoredPatterns.hasMatch(firstLine)) {
        return _toTitleCase(
          firstLine.replaceAll(RegExp(r'[^\w\sáéíóúÁÉÍÓÚñÑ&.-]'), '').trim(),
        );
      }
    }
    return null;
  }

  // ─── Extracción de nombre de producto ────────────────────────────────────

  /// Extrae el nombre del primer producto/item de la boleta.
  /// Busca líneas entre la cabecera y el total que parecen ítems de compra.
  String? _extractProductName(String text) {
    final lines = text.split('\n');

    // Líneas que NO son nombres de producto
    final skipPatterns = RegExp(
      r'^(\d+\s*@|\d+\s*x)|\bRUC\b|www\.|^\d{6,}|^[a-zA-Z0-9]{2,4}-\d+|^\d{2}/\d{2}/\d{2,4}|Venta mostrador|Cliente|Fecha|DNI|Hora:|Ticket|Cajero|Des[ce]r.*pci[oó]n|Cant\b|BOLETA DE VENTA|BE\d{2}-',
      caseSensitive: false,
    );
    final quantityStripPattern = RegExp(
      r'^\d+[\.,]?\d*\s+(und|unid|uni|six|dsp|kg|gr|lt|pck|pack|caja)\b\s*',
      caseSensitive: false,
    );

    final List<String> candidates = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (!skipPatterns.hasMatch(line) &&
          line.length > 3 &&
          !RegExp(r'^\d+[\.,]\d{2}$').hasMatch(line)) {
        // Eliminar cabeceras obvias de la tienda
        if (!line.toUpperCase().contains('MAYORISTA') &&
            !line.toUpperCase().contains('EIRL')) {
          final strippedLine = line
              .replaceFirst(quantityStripPattern, '')
              .trim();
          if (strippedLine.isNotEmpty && strippedLine.length >= 3) {
            candidates.add(strippedLine);
          }
        }
      }
    }

    if (candidates.isEmpty) return null;

    // Seleccionar el candidato que tenga menos números y más letras
    String? bestCandidate;
    double bestScore = -1.0;

    for (var candidate in candidates) {
      String clean = candidate.replaceAll(RegExp(r'\d{6,}'), '').trim();
      clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (clean.length < 3) continue;

      int letterCount = clean.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
      int numCount = clean.replaceAll(RegExp(r'[^0-9]'), '').length;

      // Fórmula heurística
      double score = letterCount.toDouble();
      if (numCount > letterCount && numCount > 5) score -= (numCount * 0.5);

      // Penalizar descripciones que parecen ser códigos de bolsa
      if (clean.toUpperCase().contains('MONFER') ||
          clean.toUpperCase().contains('UNI')) {
        score -= 20.0;
      }

      // Bonus para modelos de productos técnicos comunes (letras mayusculas + numeros)
      if (RegExp(r'[A-Z]+ \d+[A-Za-z]*').hasMatch(clean)) {
        score += 15.0;
      }

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = clean;
      }
    }

    if (bestCandidate == null) return null;
    return _toTitleCase(bestCandidate);
  }

  // ─── Extracción de ítems múltiples ───────────────────────────────────────

  List<ReceiptItem> _extractMultipleItems(String text) {
    final lines = text.split('\n');
    bool inItemsSection = false;

    const headerMarkers = [
      'cant',
      'cantidad',
      'descripcion',
      'descripción',
      'detalle',
      'producto',
    ];
    const endMarkers = [
      'total',
      'subtotal',
      'importe',
      'inporte',
      'son:',
      'vendedor',
      'cajero',
      'openpay',
      'visa',
      'mastercard',
      'efectivo',
      'vuelto',
    ];

    final skipPatterns = RegExp(
      r'^(\d+\s*@|\d+\s*x)|\bRUC\b|www\.|^\d{6,}|^[a-zA-Z0-9]{2,4}-\d+|^\d{2}/\d{2}/\d{2,4}|Venta mostrador|Cliente|Fecha|DNI|Hora:|Ticket|Cajero|Des[ce]r.*pci[oó]n|Cant\b',
      caseSensitive: false,
    );
    final quantityStripPattern = RegExp(
      r'^\d+[\.,]?\d*\s+(und|unid|uni|six|dsp|kg|gr|lt|pck|pack|caja)\b\s*',
      caseSensitive: false,
    );

    // Regex para nombre seguido de precio al final: "LECHE 3.40"
    final priceAtEndMatches = RegExp(
      r'(.*?)(?:S/|PEN|\$)?\s*(\d+[.,]\d{2})$',
      caseSensitive: false,
    );

    final List<ReceiptItem> items = [];
    String pendingName = "";

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final lower = line.toLowerCase();

      // Detectar inicio/fin
      if (!inItemsSection && headerMarkers.any((m) => lower.contains(m))) {
        inItemsSection = true;
        continue;
      }
      if (inItemsSection &&
          endMarkers.any((m) => lower.startsWith(m) || lower == m)) {
        break;
      }

      if (inItemsSection) {
        if (skipPatterns.hasMatch(line)) continue;
        final processedLine = line
            .replaceFirst(quantityStripPattern, '')
            .trim();
        if (processedLine.isEmpty) continue;

        final match = priceAtEndMatches.firstMatch(processedLine);
        if (match != null) {
          String name = match.group(1)!.trim();
          double price = double.parse(match.group(2)!.replaceAll(',', '.'));

          if (name.isEmpty) {
            // Línea solo tenía el precio, usamos el pendingName recolectado previamente
            if (pendingName.isNotEmpty && price > 0) {
              items.add(
                ReceiptItem(name: _toTitleCase(pendingName), price: price),
              );
              pendingName = "";
            }
          } else {
            // Limpiar códigos largos
            name = name.replaceAll(RegExp(r'\d{6,}'), '').trim();
            if (name.length >= 2 && price > 0) {
              if (pendingName.isNotEmpty) {
                name = "$pendingName $name".trim();
                pendingName = "";
              }
              items.add(ReceiptItem(name: _toTitleCase(name), price: price));
            }
          }
        } else {
          // No hay precio al final, podría ser un producto mutilínea
          String nameOnly = processedLine
              .replaceAll(RegExp(r'\d{6,}'), '')
              .trim();
          if (nameOnly.length >= 3 &&
              !RegExp(r'^\d+[\.,]\d{2}$').hasMatch(processedLine)) {
            pendingName += " $nameOnly";
            pendingName = pendingName.trim();
          }
        }
      }
    }
    return items;
  }

  static String _toTitleCase(String text) {
    return text
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? ''
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  void dispose() {
    _textRecognizer.close();
  }
}
