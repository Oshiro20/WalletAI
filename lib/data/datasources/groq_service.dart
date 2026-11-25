import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';

/// Resultado estructurado de la autocategorización IA (categoría + subcategoría
/// existente o sugerencia de crear una nueva).
class AiCategoryPrediction {
  final String? categoryName;
  final String? subcategoryName;
  final bool isNewCategory;
  final bool isNewSubcategory;
  final String? iconEmoji;
  final String? reason;

  const AiCategoryPrediction({
    this.categoryName,
    this.subcategoryName,
    this.isNewCategory = false,
    this.isNewSubcategory = false,
    this.iconEmoji,
    this.reason,
  });

  bool get hasNewSuggestion =>
      (isNewCategory && (categoryName?.trim().isNotEmpty ?? false)) ||
      (isNewSubcategory && (subcategoryName?.trim().isNotEmpty ?? false));
}

/// Servicio que conecta con el router Multi-IA del backend de WalletAI
/// (Cloudflare Workers AI, Gemini, OpenRouter, Mistral).
class GroqService {
  static String get _baseUrl => AppConfig.apiBaseUrl;

  /// Pre-calienta el servidor (útil para evitar cold starts de Render mientras el usuario habla).
  static Future<void> warmUpServer() async {
    try {
      final healthUrl = _baseUrl.replaceFirst(RegExp(r'/api/?$'), '/health');
      await http
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Silencioso: solo intenta despertar el backend sin bloquear la UI.
    }
  }

  static const String _systemPrompt = '''
Eres WalletAI, el asistente financiero personal inteligente integrado en la app de finanzas del usuario.
Tu rol es analizar sus finanzas reales y responder con precisión usando sus datos del aplicativo.

Reglas estrictas:
- Responde SIEMPRE en español peruano/latinoamericano.
- Sé conciso, claro y accionable (máximo 3-4 párrafos cortos o viñetas limpias).
- Usa emojis con moderación para hacer las respuestas más visuales.
- PRIORIZA SIEMPRE los "DATOS FINANCIEROS REALES DEL USUARIO" proporcionados abajo: cita montos, cuentas, categorías, subcategorías, presupuestos, metas, cuotas, pagos recurrentes y fechas exactas.
- NUNCA respondas con consejos meramente genéricos si existen cifras del usuario aplicables a la pregunta; analiza sus números reales y da recomendaciones basadas en ellos.
- Si el usuario pregunta por un gasto, categoría, mes o concepto que NO aparece en sus datos proporcionados, indícalo explícitamente ("No encontré registros de X en tus datos") en lugar de inventar cifras.
- No inventes transacciones, saldos ni porcentajes que no estén en el contexto.
- La moneda principal son soles peruanos (S/).''';

  /// Historial de mensajes (rol + contenido limpio) para mantener el contexto de la conversación
  final List<Map<String, String>> _history = [];

  GroqService();

  /// Envía un mensaje al modelo con contexto financiero real y respaldo local opcional
  Future<String> sendMessage(
    String userMessage, {
    String? financialContext,
    Future<String> Function(String query)? offlineFallback,
  }) async {
    final cleanQuestion = userMessage.trim();

    // Construir systemPrompt enriquecido con los datos reales actuales y memoria reciente
    final sysBuffer = StringBuffer(_systemPrompt);

    if (financialContext != null && financialContext.isNotEmpty) {
      sysBuffer.writeln('\n\n=== DATOS FINANCIEROS REALES DEL USUARIO ===');
      sysBuffer.writeln(financialContext);
    }

    if (_history.isNotEmpty) {
      sysBuffer.writeln('\n\n=== CONVERSACIÓN RECIENTE ===');
      final recentHistory = _history.length > 8
          ? _history.sublist(_history.length - 8)
          : _history;
      for (final msg in recentHistory) {
        final roleLabel = msg['role'] == 'user' ? 'Usuario' : 'WalletAI';
        sysBuffer.writeln('$roleLabel: ${msg['content']}');
      }
    }

    _history.add({'role': 'user', 'content': cleanQuestion});

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/parse-voice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemPrompt': sysBuffer.toString(),
              'userMessage': cleanQuestion,
            }),
          )
          .timeout(const Duration(seconds: 55));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final assistantMessage =
            data['choices'][0]['message']['content'] as String;

        // Guardar respuesta en historial para contexto futuro
        _history.add({'role': 'assistant', 'content': assistantMessage});

        // Limitar historial a últimos 20 mensajes
        if (_history.length > 20) {
          _history.removeRange(0, 2);
        }

        return assistantMessage;
      } else {
        _history.removeLast(); // Revertir mensaje fallido

        if (offlineFallback != null) {
          final localReply = await offlineFallback(cleanQuestion);
          return '$localReply\n\n_ℹ️ Respuesta generada localmente con tus datos (servidor IA ocupado: ${response.statusCode})._';
        }

        String errorMsg = 'Error desconocido';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null) {
            if (errorData['error'] is String) {
              errorMsg = errorData['error'];
            } else if (errorData['error'] is Map) {
              errorMsg = errorData['error']['message'] ?? 'Error desconocido';
            }
          }
        } catch (_) {
          errorMsg = 'HTTP ${response.statusCode}';
        }

        if (response.statusCode == 401) {
          return '🔑 Las credenciales de IA en el servidor no son válidas o están ausentes.';
        } else if (response.statusCode == 429) {
          return '⏳ Límite de consultas alcanzado. Espera un momento e intenta de nuevo.';
        }

        return '❌ Error del servidor IA (${response.statusCode}): $errorMsg';
      }
    } catch (e) {
      _history.removeLast();
      if (offlineFallback != null) {
        final localReply = await offlineFallback(cleanQuestion);
        return '$localReply\n\n_ℹ️ Respuesta generada con tus datos locales (sin conexión al servidor IA)._';
      }
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Network')) {
        return _offlineResponse(userMessage);
      }
      return '❌ Error de conexión: $e';
    }
  }

  /// Respuestas inteligentes predefinidas para cuando no hay internet
  String _offlineResponse(String query) {
    final q = query.toLowerCase();

    if (q.contains('gasto') || q.contains('gasté') || q.contains('cuánto')) {
      return '📊 Sin conexión — Consejo de gastos:\n\n'
          'La regla 50/30/20 es una excelente guía:\n'
          '• **50%** de tus ingresos para necesidades (alquiler, comida, servicios)\n'
          '• **30%** para deseos (entretenimiento, ropa)\n'
          '• **20%** para ahorro e inversión\n\n'
          '_Reconéctate a internet para ver tus datos reales y un análisis personalizado._';
    }

    if (q.contains('ahorro') || q.contains('ahorrar') || q.contains('meta')) {
      return '💰 Sin conexión — Tip de ahorro:\n\n'
          'La estrategia más efectiva es el **ahorro automático**:\n'
          '• Separa el 20% de cada ingreso antes de gastar\n'
          '• Define una meta específica con fecha límite\n'
          '• Revisa tu progreso semanalmente\n\n'
          '_Crea una meta en la app para hacer seguimiento automático._';
    }

    if (q.contains('presupuesto') ||
        q.contains('budget') ||
        q.contains('límite')) {
      return '📋 Sin conexión — Sobre presupuestos:\n\n'
          'Un buen presupuesto mensual debería incluir:\n'
          '• Gastos fijos: alquiler, servicios, deudas\n'
          '• Gastos variables: alimentación, transporte\n'
          '• Ahorro: mínimo 10-20% de tus ingresos\n'
          '• Fondo de emergencia: 3-6 meses de gastos\n\n'
          '_Configura presupuestos por categoría en la sección Presupuestos._';
    }

    if (q.contains('inversión') ||
        q.contains('invertir') ||
        q.contains('interés')) {
      return '📈 Sin conexión — Tip de inversión:\n\n'
          'Para empezar a invertir en Perú:\n'
          '• **Fondos Mutuos** (BBVA, Intercorp): desde S/ 100\n'
          '• **CTS**: maximiza tu rendimiento negociando la tasa\n'
          '• **AFP Voluntaria**: deducción de impuestos\n'
          '• **Dólares**: cobertura ante devaluación del sol\n\n'
          '_Reconéctate para un consejo personalizado según tus datos._';
    }

    if (q.contains('deuda') || q.contains('crédito') || q.contains('tarjeta')) {
      return '💳 Sin conexión — Gestión de deudas:\n\n'
          'Estrategias para eliminar deudas:\n'
          '• **Avalancha**: paga primero la deuda con mayor interés\n'
          '• **Bola de nieve**: paga primero la deuda más pequeña\n'
          '• Nunca pagues solo el mínimo de tarjeta de crédito\n'
          '• Evita tomar nueva deuda mientras tienes activa\n\n'
          '_Registra tus deudas en Cuentas para hacer seguimiento._';
    }

    // Respuesta genérica
    return '📵 Sin conexión a internet\n\n'
        'No puedo conectarme al asistente IA en este momento.\n\n'
        '**Mientras tanto, puedo recordarte que:**\n'
        '• Revisa tus transacciones del mes en la pestaña 📋\n'
        '• Verifica el progreso de tus presupuestos\n'
        '• Consulta el análisis de gastos en la pestaña 📊\n\n'
        '_Intenta de nuevo cuando tengas conexión._';
  }

  /// Reinicia el historial de conversación (nueva sesión)
  void resetSession() {
    _history.clear();
  }

  /// Hidrata la memoria conversacional con mensajes previos persistidos
  void loadHistory(List<Map<String, String>> messages) {
    _history.clear();
    final trimmed = messages.length > 20
        ? messages.sublist(messages.length - 20)
        : messages;
    for (final m in trimmed) {
      final role = m['role'];
      final content = m['content'] ?? '';
      if ((role == 'user' || role == 'assistant') && content.isNotEmpty) {
        _history.add({'role': role!, 'content': content});
      }
    }
  }

  /// PROCESAMIENTO OCR: Analiza el texto en bruto de una boleta y devuelve JSON estructurado
  Future<Map<String, dynamic>?> parseReceipt(
    String rawText, {
    bool isMultiple = false,
  }) async {
    final currentDate = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);

    final promptSimple =
        '''
1️⃣ ROL DEL SISTEMA
Actúa como un Especialista Senior en:
- OCR financiero, Procesamiento de tickets comerciales, Normalización de texto ruidoso y Clasificación semántica jerárquica.
Tu tarea es analizar una boleta peruana y devolver datos estructurados listos para la base de datos del aplicativo.
HOY ES: $formattedDate. Usa este año/mes como base si la boleta tiene fechas incompletas o dudosas.

2️⃣ OBJETIVO Y FORMATO DE SALIDA (OBLIGATORIO JSON EXACTO)
Extraer datos y devolver ESTE JSON EXACTO:
{
  "comercio": "cadena con el nombre de la tienda",
  "fecha": "cadena en formato YYYY-MM-DD",
  "modo_escaneo": "SIMPLE",
  "productos": [
    {
      "nombre_producto": "cadena normalizada del producto sin incluir la métrica o peso",
      "cantidad": 1,
      "unidad": "cadena (Ej: KG, UND, LT, GRS)",
      "precio_unitario": 0.00,
      "importe_total": 0.00,
      "categoria": "categoría principal",
      "subcategoria": "subcategoría"
    }
  ],
  "total_boleta": 0.00,
  "observaciones": ""
}
Solo devuelve JSON puro válido.

3️⃣ IGNORAR COMPLETAMENTE
Marcas de agua de la cámara del celular (Ej: "POCO X6 Pro 5G", "Shot on iPhone", "Redmi", "Samsung"), Líneas decorativas, RUC, Mensajes legales, Datos del cajero.
PALABRAS CLAVE QUE NO SON PRODUCTOS: "Caja", "Caja 99", "Tienda", "Secuencia", "Nro. Documento", "DNI", "Fecha", "Sub-total", "Descuento", "Cant.", "Total", "Producto", "SKU", "DETALLES DE TU COMPRA". IGNÓRALOS Y NUNCA LOS ASIGNES COMO NOMBRES DE PRODUCTOS. ¡CUIDADO! Un encabezado como "Caja 99" mezclado en la boleta no es el producto "Caja" a 99 soles. Un producto válido siempre está acompañado de un precio importe colindante y suele listarse después de cabeceras de tabla (Ej: "Descripción", "IMPORT.").

4️⃣ NORMALIZACIÓN Y PRECISIÓN EXPERTA (CRÍTICO)
Convertir a mayúsculas y simplificar (Ej: "SET P/ELECTRICISTA 2 PZAS" -> "SET ELECTRICISTA").
REGLA DE CANTIDAD Y UNIDAD: Si el producto menciona un peso o tamaño (Ej: "ARROZ 1KG", "PLATANO X 4 UND"), separa la cantidad ("1" o "4"), la unidad ("KG" o "UND") y deja el nombre limpio ("ARROZ", "PLATANO"). Si no hay unidad explícita, usa "UND".
REGLA DE LECTURA: El escáner (OCR) a veces lee TODO EL BLOQUE izquierdo (nombres) y luego TODO EL BLOQUE derecho (precios y cantidades) muy abajo. Mapea el primer precio encontrado con el primer producto, el segundo con el segundo, etc. de manera muy inteligente y secuencial si detectas que están separados.

5️⃣ SISTEMA DE CATEGORIZACIÓN (USAR EXACTAMENTE ESTAS)
🏠 ALOJAMIENTO: Servicios del Hogar, Limpieza del Hogar, Mantenimiento, Electrodomésticos, Decoración/Muebles.
💡 SERVICIOS DIGITALES.
🚗 TRANSPORTE: Transporte Público, Taxi/Uber, Gasolina, Estacionamiento/Peaje.
📚 EDUCACIÓN.
🏥 SALUD: Farmacia/Botica, Citas Médicas, Gimnasio.
🍽 ALIMENTACIÓN: Mercado/Supermercado, Restaurante, Delivery.
❤️ PAREJA: Salida Romántica, Regalos/Detalles, Plan Especial, Detalles del Día.
💼 TRABAJO.
🎮 ENTRETENIMIENTO: Streaming, Cine/Salidas, Videojuegos, Libros/Revistas.
👕 ROPA: Ropa, Calzado, Ropa Deportiva, Accesorios de Moda.
🧴 CUIDADO PERSONAL: Peluquería/Barbería, Higiene/Cosméticos, Estética.
🐶 MASCOTAS: Alimento, Veterinario, Accesorios/Higiene.
✨ ANTOJOS/IMPULSOS: Snacks/Antojos.
🏋️ DEPORTE/FITNESS: Membresía Gimnasio, Equipamiento Deportivo, Clases/Actividades, Nutrición Deportiva.
🚘 VEHÍCULO: Lavado de Auto, Mecánica/Repuestos, Peajes/SOAT.
✈️ VIAJES: Pasajes, Hospedaje, Tours/Actividades.
🎁 REGALOS/DONACIONES: Regalos, Donaciones/Propinas.
📈 INVERSIONES: Fondo Mutuo/Ahorro, Acciones/Bolsa, Criptomonedas.
📦 OTRO.

6️⃣ REGLAS INTELIGENTES DE CLASIFICACIÓN (CRÍTICO)
Ejemplos de categorización avanzada:
- Herramientas y ferretería (cinta aislante, destornillador, taladro, martillo, candado, clavos, pintura, pegamento, set electricista, silicona) -> ALOJAMIENTO > Mantenimiento. ¡NUNCA VEHÍCULO!
- Electrodomésticos y tecnología para casa (focos, enchufes, cables, TV, licuadora, pilas) -> ALOJAMIENTO > Electrodomésticos.
- Limpieza (desengrasante, lejía, escoba, detergente, lavavajilla) -> ALOJAMIENTO > Limpieza del Hogar.
- Comestibles (leche, fideos, carne, huevos, galletas, pan, queso) -> ALIMENTACIÓN > Mercado/Supermercado.
- Repuestos de auto (aceite de motor, limpiaparabrisas, llantas, batería, refrigerante, cera) -> VEHÍCULO > Mecánica/Repuestos.
- Combustible (gasolina, diesel, GNV) -> VEHÍCULO > Gasolina.
- Farmacia (pastillas, alcohol, curitas, vitaminas, paracetamol) -> SALUD > Farmacia/Botica.
- Útiles y papelería (cuadernos, lapiceros, hojas bond) -> EDUCACIÓN.
- Muebles y organización (sillas, mesas, cortinas, cajas organizadoras, cajas de plástico, tapers) -> ALOJAMIENTO > Decoración/Muebles.
- Mascotas (comida perro, arena gato) -> MASCOTAS > Alimento o Accesorios/Higiene.
Si no coincide con nada obvio -> OTRO. Nunca inventar categoría.

ENFÓCATE EN LA VERSIÓN SIMPLE, EXTRACCION DE UN SOLO PRODUCTO PRINCIPAL.

Texto OCR a analizar:
''';

    final promptMultiple =
        '''
1️⃣ ROL DEL SISTEMA

Actúa como un Arquitecto Senior en:
- OCR financiero avanzado
- Procesamiento de tickets comerciales largos
- Normalización robusta de texto OCR ruidoso
- Parsing estructurado de columnas desalineadas
- Validación contable automática
- Clasificación semántica jerárquica
- Sistemas de aprendizaje incremental

Tu misión es extraer con precisión TODOS los productos de una boleta peruana multiproducto y devolver datos estructurados listos para base de datos financiera.

Precisión > velocidad.
Consistencia contable > inferencia apresurada.

---

2️⃣ OBJETIVO
HOY ES: $formattedDate. Si la boleta tiene una fecha incompleta o dudosa, asume que es cercana a esta fecha.
Analizar texto OCR de una boleta multiproducto y devolver JSON estructurado exacto.

Siempre:
"modo_escaneo": "MULTIPLE"

---

3️⃣ SALIDA OBLIGATORIA (JSON PURO VÁLIDO, SIN TEXTO EXTRA)

{
  "comercio": "",
  "fecha": "YYYY-MM-DD",
  "modo_escaneo": "MULTIPLE",
  "productos": [
    {
      "nombre_producto": "cadena normalizada sin métrica ni peso",
      "cantidad": 1,
      "unidad": "cadena (Ej: KG, UND, LT, GRS)",
      "precio_unitario": 0.00,
      "importe_total": 0.00,
      "categoria": "",
      "subcategoria": "",
      "confianza_clasificacion": 0.00
    }
  ],
  "subtotal_detectado": 0.00,
  "descuentos_detectados": 0.00,
  "total_boleta": 0.00,
  "coherencia_total": true,
  "observaciones": "",
  "aprendizaje_sugerido": [
    {
      "producto_detectado": "",
      "categoria_confirmada": "",
      "subcategoria_confirmada": ""
    }
  ]
}

Nunca incluir texto fuera del JSON.

---

4️⃣ FILTRADO ESTRICTO (ANTI-RUIDO)

Ignorar completamente:

- Marcas de agua de cámara de celular (Ej: "POCO X6 Pro 5G", "Shot on iPhone", "Redmi", "Samsung", timestamps cámara)
- QR
- Hash
- RUC
- DNI
- Cajero
- Palabras sueltas engañosas de cabeceras: "Caja" aislada, "Tienda", "Caja 01", "Caja 99" o simplemente el número de caja (Ej: "99"). ¡No son productos ni precios válidos!
- Subtotal (como producto)
- Total (como producto)
- La palabra SKU y el código al lado (Ej: SKU 154943, SKU 64981)
- Mensajes legales
- Secuencia, documento, serie

Si una línea no es UN PRODUCTO DESCRIPTIVO REAL (Ej: "CINTA AISLANTE"), NO es un producto. Y si un número no tiene punto decimal claro o no es una cantidad, tampoco es dinero.

---

5️⃣ PARSING AVANZADO (CRÍTICO)

📌 REGLA 1 – ORDEN LÓGICO DE MAPEO (CRÍTICO)
Si el escáner partió el documento y el OCR devuelve todos los nombres juntos arriba y todos los precios juntos muy abajo.

Paso 1: PURIFICA. Antes de emparejar, elimina de tu lista mental palabras basura ("Caja", "99", "SKU", "DETALLES", etc). ¡Quédate estrictamente con una lista de PRODUCTOS REALES (Ej: CINTA, CANDADO, CANDADO, SET) y otra lista de PRECIOS CON DECIMALES (4.90, 8.90, 8.90, 24.90)! No fusiones duplicados todavía.
Paso 2: CUENTA. Asegúrate de tener la misma cantidad de Productos Reales purificados [N] y de Precios purificados [N].
Paso 3: MAPEA 1 A 1 en ese exacto orden:
producto_real[0] <-> precio_purificado[0]
producto_real[1] <-> precio_purificado[1]
producto_real[n] <-> precio_purificado[n]
¡No te saltes ningún número con decimales ni ningún producto descriptivo de la lista limpia!

📌 REGLA 2 – Detección de patrón monetario
Un precio válido cumple:
- Tiene punto decimal
- Tiene 2 decimales
- Está al final de línea o columna

📌 REGLA 3 – Consolidación de duplicados (SOLO AL FINAL)
SOLO DESPUÉS de haber emparejado 1 a 1 cada ítem con su precio individual:
Si un mismo producto aparece varias veces:
- Unificar en uno solo
- Sumar cantidad
- Sumar importe_total (precio1 + precio2)

Ej: Emparejaste (CANDADO 8.90) y luego (CANDADO 8.90).
Al crear el JSON, pon 1 solo CANDADO:
→ cantidad: 2
→ importe_total: 17.80

📌 REGLA 4 – Cantidad y Unidad
Si no aparece cantidad explícita: → asumir cantidad = 1
Si el nombre incluye pesaje o unidades (Ej: "ARROZ 1KG", "OFERTA BEBIDAS 2 LTR"):
- Sepáralo en cantidad (1, 2)
- Extrae la unidad ("KG", "LTR")
- Limpia el nombre_producto ("ARROZ", "BEBIDAS")
Si no indica unidad y es por pieza, usa "UND".
¡REGLA DE ORO PROHIBITIVA!: NUNCA MULTIPLIQUES CANTIDAD POR PRECIO. NUNCA. Está absolutamente prohibido hacer cálculos matemáticos para deducir el precio. El precio que extraigas DEBE SER LITERALMENTE uno de los números que aparece en la columna derecha de la boleta para esa línea. Si en la boleta dice "LECHE 24UND" y a la derecha dice "7.50", el `importe_total` de esa fila ES 7.50 EXACTAMENTE. No inventes 180.
El `precio_unitario` puedes calcularlo SOLO dividiendo el `importe_total` detectado entre la cantidad detectada. Pero el `importe_total` JAMÁS se multiplica.

📌 REGLA 5 – Descuentos
Detectar líneas tipo:
- DESCUENTO
- PROMOCIÓN
- OFERTA

Sumar en descuentos_detectados
No tratar como producto.

---

6️⃣ VALIDACIÓN CONTABLE OBLIGATORIA

A) Validar:
cantidad × precio_unitario ≈ importe_total

B) Validar:
Σ importe_total ≈ total_boleta - descuentos

C) Si diferencia > 0.10:
coherencia_total = false
Agregar detalle en observaciones

---

7️⃣ NORMALIZACIÓN AVANZADA

- Convertir a MAYÚSCULAS
- Eliminar caracteres basura
- Expandir abreviaciones comunes:
  CHOCOL → CHOCOLATE
  UND → eliminar
  DSP → eliminar
  X12 → eliminar
- Quitar marcas innecesarias

Ej:
"GOLD MARINO FILETE/CABALLA 170GRX48UND"
→ "FILETE CABALLA 170GR"

---

8️⃣ CLASIFICACIÓN JERÁRQUICA (OBLIGATORIA)

Usar EXACTAMENTE esta jerarquía (no inventar categorías nuevas).
🏠 ALOJAMIENTO: Servicios del Hogar, Limpieza del Hogar, Mantenimiento, Electrodomésticos, Decoración/Muebles.
💡 SERVICIOS DIGITALES.
🚗 TRANSPORTE: Transporte Público, Taxi/Uber, Gasolina, Estacionamiento/Peaje.
📚 EDUCACIÓN.
🏥 SALUD: Farmacia/Botica, Citas Médicas, Gimnasio.
🍽 ALIMENTACIÓN: Mercado/Supermercado, Restaurante, Delivery.
❤️ PAREJA: Salida Romántica, Regalos/Detalles, Plan Especial, Detalles del Día.
💼 TRABAJO.
🎮 ENTRETENIMIENTO: Streaming, Cine/Salidas, Videojuegos, Libros/Revistas.
👕 ROPA: Ropa, Calzado, Ropa Deportiva, Accesorios de Moda.
🧴 CUIDADO PERSONAL: Peluquería/Barbería, Higiene/Cosméticos, Estética.
🐶 MASCOTAS: Alimento, Veterinario, Accesorios/Higiene.
✨ ANTOJOS/IMPULSOS: Snacks/Antojos.
🏋️ DEPORTE/FITNESS: Membresía Gimnasio, Equipamiento Deportivo, Clases/Actividades, Nutrición Deportiva.
🚘 VEHÍCULO: Lavado de Auto, Mecánica/Repuestos, Peajes/SOAT.
✈️ VIAJES: Pasajes, Hospedaje, Tours/Actividades.
🎁 REGALOS/DONACIONES: Regalos, Donaciones/Propinas.
📈 INVERSIONES: Fondo Mutuo/Ahorro, Acciones/Bolsa, Criptomonedas.
📦 OTRO.

---

9️⃣ MOTOR DE CLASIFICACIÓN INTELIGENTE

Sistema híbrido:

A) Coincidencia por palabra clave
B) Contexto del comercio
C) Historial previo (aprendizaje incremental)
D) Similitud semántica

Ejemplo:
Si comercio es supermercado
→ Priorizar ALIMENTACIÓN

Si comercio es ferretería
→ Priorizar ALOJAMIENTO > Mantenimiento

---

🔟 APRENDIZAJE INCREMENTAL (MUY IMPORTANTE)

Cada vez que se procese una boleta:

Si un producto ya fue clasificado antes en sesiones anteriores:
→ Priorizar esa categoría automáticamente
→ Aumentar confianza_clasificacion

Si usuario corrige categoría:
→ Guardar en aprendizaje_sugerido
→ En futuras boletas aplicar esa regla

Simular aprendizaje usando:
"aprendizaje_sugerido": []

---

1️⃣1️⃣ CONFIANZA DE CLASIFICACIÓN

Agregar campo:
"confianza_clasificacion": valor entre 0 y 1

0.95 = palabra clave directa
0.75 = inferencia contextual
0.50 = ambigua
0.30 = baja certeza

---

1️⃣2️⃣ REGLAS CRÍTICAS

- Nunca clasificar herramientas (candados, cinta aislante, taladros, set electricista) como VEHÍCULO. Siempre ALOJAMIENTO > Mantenimiento.
- Nunca clasificar comida como MASCOTAS salvo que contenga palabra perro/gato.
- Nunca clasificar limpieza (desengrasante, lejía) como ALIMENTACIÓN.
- Muebles y organización (cajas organizadoras, cajas de plástico, tapers, caja) -> ALOJAMIENTO > Decoración/Muebles.
- Nunca inventar productos no visibles ni mapear precios rotos a "Cajas".

---

1️⃣3️⃣ OBJETIVO FINAL

El JSON debe estar listo para:

- Guardar en base de datos
- Generar gráficos
- Activar alertas
- Aprender del usuario
- Mejorar precisión en futuras boletas

Si hay ambigüedad -> clasificar con menor confianza.
Nunca inventar.
Nunca mezclar columnas.
Nunca duplicar productos.

Texto OCR a analizar:
''';

    final activePrompt = isMultiple ? promptMultiple : promptSimple;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/parse-receipt'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemPrompt': activePrompt,
              'base64Image': rawText,
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;

        // Limpiar bloques de markdown del texto si existen
        String cleanContent = content;
        if (cleanContent.contains('```json')) {
          cleanContent = cleanContent.split('```json')[1];
        } else if (cleanContent.contains('```')) {
          cleanContent = cleanContent.split('```')[1];
        }
        if (cleanContent.contains('```')) {
          cleanContent = cleanContent.split('```')[0];
        }
        cleanContent = cleanContent.trim();

        return jsonDecode(cleanContent) as Map<String, dynamic>?;
      }
    } catch (_) {
      // Si falla, caerá al fallback local
    }
    return null;
  }

  /// Limpia bloques Markdown (```json ... ```) y extrae un objeto JSON válido.
  static Map<String, dynamic>? decodeJsonObject(String raw) {
    var clean = raw.trim();
    if (clean.contains('```')) {
      clean = clean.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
      clean = clean.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
      clean = clean.replaceAll(RegExp(r'```(?:json)?\s*'), '');
      clean = clean.replaceAll('```', '');
      clean = clean.trim();
    }

    final start = clean.indexOf('{');
    final end = clean.lastIndexOf('}');
    if (start != -1 && end > start) {
      clean = clean.substring(start, end + 1);
    }

    try {
      final decoded = jsonDecode(clean);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String _buildCategoryTree(
    List<dynamic> categories,
    List<dynamic> subcategories,
  ) {
    if (categories.isEmpty) return 'Sin categorías registradas';
    final subsByCat = <String, List<String>>{};
    for (final s in subcategories) {
      final catId = (s as dynamic).categoryId?.toString();
      final name = (s as dynamic).name?.toString();
      if (catId != null && name != null && name.trim().isNotEmpty) {
        subsByCat.putIfAbsent(catId, () => []).add(name.trim());
      }
    }
    return categories.map((c) {
      final id = (c as dynamic).id?.toString() ?? '';
      final name = (c as dynamic).name?.toString() ?? '';
      final subs = subsByCat[id] ?? const <String>[];
      return subs.isEmpty ? '- $name' : '- $name: [${subs.join(', ')}]';
    }).join('\n');
  }

  /// PROCESAMIENTO VOZ: Analiza un texto dictado por el usuario y extrae información estructurada
  /// incluyendo categoría, subcategoría, sugerencias de creación y soporte multi-producto (`items`).
  Future<Map<String, dynamic>?> parseVoiceTransaction(
    String rawVoice,
    List<dynamic> categories, {
    List<dynamic> subcategories = const [],
    List<dynamic> accounts = const [],
    DateTime? referenceDate,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final now = referenceDate ?? DateTime.now();
    final todayIso = DateFormat('yyyy-MM-dd').format(now);
    final weekdayName = DateFormat('EEEE', 'es').format(now);
    final categoryTree = _buildCategoryTree(categories, subcategories);
    final accountsListStr = accounts.isEmpty
        ? 'No especificadas'
        : accounts
              .map((a) {
                final type = (a as dynamic).type?.toString() ?? '';
                final typeLabel = switch (type) {
                  'credit_card' => 'Tarjeta de Crédito',
                  'bank' => 'Banco',
                  'wallet' => 'Billetera',
                  'cash' => 'Efectivo',
                  _ => type,
                };
                return '${a.name} [$typeLabel]';
              })
              .join(', ');

    final prompt =
        '''
1️⃣ ROL DEL SISTEMA
Eres el parser NLP financiero de WalletAI (Perú/Latam). Tu tarea es transformar un dictado de voz en lenguaje natural en un único objeto JSON estructurado para registrar la transacción sin errores.

2️⃣ CONTEXTO ACTUAL DEL USUARIO
- Fecha de hoy: $todayIso ($weekdayName)
- Árbol de categorías y subcategorías del usuario:
$categoryTree
- Cuentas/tarjetas del usuario: $accountsListStr

3️⃣ FORMATO DE SALIDA (JSON EXACTO)
Devuelve ÚNICAMENTE este objeto JSON con las mismas claves:
{
  "tipo": "expense", // "expense", "income" o "transfer"
  "monto": 0.00, // monto total decimal positivo
  "moneda": "PEN", // "PEN" (soles/lucas), "USD" (dólares/verdes) o "EUR"
  "descripcion": "Comercio o motivo limpio sin muletillas",
  "producto": null, // nombre específico del producto/servicio principal o null
  "cantidad": 1, // número (ej. 2 si dijo "2 kilos de pollo", sino 1)
  "unidad": "UND", // "UND", "KG", "GRS", "LTR", "CAJA" o "MTS"
  "categoria_sugerida": "Nombre exacto de categoría existente o propuesta si no existe ninguna adecuada",
  "subcategoria_sugerida": null, // nombre exacto de subcategoría existente o propuesta si ninguna encaja
  "es_nueva_categoria": false,
  "es_nueva_subcategoria": false,
  "cuenta_sugerida": null, // nombre exacto de la cuenta/tarjeta origen o null
  "cuenta_destino_sugerida": null, // nombre exacto de cuenta destino solo en "transfer" o pago de tarjeta, sino null
  "fecha": "$todayIso", // formato YYYY-MM-DD (resuelve "ayer", "antier", "el lunes", etc.)
  "cuotas": 1, // entero >= 1 (ej. 3 si dijo "en 3 cuotas", sino 1)
  "items": [] // SOLO si el usuario dictó 2 o más productos con precios separados (ej. "2 kilos de pollo a 22 soles y 1 kilo de papa a 4 soles"): [{"nombre": "Pollo", "monto": 22.0, "cantidad": 2, "unidad": "KG", "categoria": "Alimentación", "subcategoria": "Mercado/Supermercado"}]
}

4️⃣ REGLAS ESTRICTAS
- Limpia muletillas del campo "descripcion" ("gasté", "pagué", "en", "soles", "con mi tarjeta"): escribe el concepto/comercio limpio.
- Si menciona "transferí", "pasé", "envié" entre cuentas propias o "pagué mi tarjeta X con Y", usa "tipo": "transfer", "cuenta_sugerida": origen (Y) y "cuenta_destino_sugerida": destino (X).
- PRIORIZA categorías y subcategorías existentes del árbol de arriba. Solo pon "es_nueva_subcategoria": true (o "es_nueva_categoria": true) si realmente ninguna existente describe bien el producto.
- Si dictó 2 o más productos con precios distintos en el mismo audio, llena "items" con cada producto y pon la suma en "monto". Si solo es 1 gasto, deja "items": [].
- Responde SOLO JSON válido sin texto extra ni bloques Markdown.
''';

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/parse-voice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemPrompt': prompt,
              'userMessage': rawVoice,
              'taskType': 'fast_json',
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        return decodeJsonObject(content);
      }
    } catch (_) {
      // Si falla, retornar null para caer en logica fallback
    }
    return null;
  }

  /// PREDICCIÓN INTELIGENTE DE CATEGORÍA Y SUBCATEGORÍA (incluye sugerencia de crear nuevas si no encaja).
  Future<AiCategoryPrediction?> predictCategoryAndSubcategory(
    String product,
    List<dynamic> categories,
    List<dynamic> subcategories, {
    String? description,
    double? amount,
    double? quantity,
    String? unit,
    String? lockedCategoryName,
  }) async {
    if (product.trim().isEmpty) return null;

    final tree = _buildCategoryTree(categories, subcategories);
    final contextParts = <String>[
      'Producto/Gasto: ${product.trim()}',
      if (description != null && description.trim().isNotEmpty)
        'Comercio/Nota: ${description.trim()}',
      if (quantity != null && quantity > 0)
        'Cantidad: $quantity${unit != null && unit.isNotEmpty ? ' $unit' : ''}',
      if (amount != null && amount > 0) 'Monto: S/ ${amount.toStringAsFixed(2)}',
      if (lockedCategoryName != null && lockedCategoryName.trim().isNotEmpty)
        'Categoría ya elegida por el usuario (RESPETARLA y solo elegir la mejor subcategoría dentro de ella): ${lockedCategoryName.trim()}',
    ];
    final userInput = contextParts.join(' | ');

    final prompt =
        '''
Eres el clasificador financiero inteligente de WalletAI (Perú/Latam).
Analiza el producto/gasto del usuario y clasifícalo usando su árbol real de categorías y subcategorías.

ÁRBOL ACTUAL DEL USUARIO:
$tree

DEVUELVE ÚNICAMENTE ESTE OBJETO JSON (sin markdown ni texto extra):
{
  "categoria": "Nombre exacto de categoría existente o nueva propuesta",
  "subcategoria": "Nombre exacto de subcategoría existente o nueva propuesta (o null)",
  "es_nueva_categoria": false,
  "es_nueva_subcategoria": false,
  "icono": "🏷️",
  "razon": "Motivo breve de 5-8 palabras"
}

REGLAS ESTRICTAS:
1. Prioriza SIEMPRE una categoría y subcategoría EXISTENTES del árbol.
2. Si se indica una "Categoría ya elegida por el usuario", devuelve EXACTAMENTE esa categoría y enfócate en escoger la mejor subcategoría dentro de ella.
3. Distinción clave en Alimentación (Perú/Latam):
   - USA Restaurante / Comida fuera / Delivery SOLO para platos ya preparados o comidas servidas fuera (ej. "Almuerzo", "Menú", "Cena", "Desayuno", "Ensalada de frutas", "Ensalada César", "Pollo a la brasa", "Ceviche", "Chifa", "Pizza", "Hamburguesa", "KFC").
   - USA Supermercado / Mercado / Víveres / Abarrotes / Verduras para ingredientes, verduras, carnes o compras de mercado (ej. "Ensalada" a secas con cantidad/mercado, "Lechuga", "Tomate", "Pollo", "Pechuga", "Huevos", "Leche", "Arroz", "Aceite").
   - USA Snacks / Golosinas / Cafetería (si existe) para galletas, chocolates, helados, piqueos; si no existe, Supermercado/Bodega o sugiere "Snacks y Dulces".
4. Si la categoría existe pero NINGUNA subcategoría actual encaja bien (ej. "Creatina" en "Deporte/Fitness" sin "Suplementos", o "ChatGPT Plus" en "Servicios Digitales" sin "Suscripciones IA"), pon "es_nueva_subcategoria": true con un nombre limpio y útil en español.
5. Solo pon "es_nueva_categoria": true si el gasto realmente no encaja en ninguna categoría existente (en vez de mandarlo a "Otro").
6. Nunca devuelvas explicaciones fuera del JSON.
''';

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/parse-voice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemPrompt': prompt,
              'userMessage': userInput,
              'taskType': 'fast_json',
            }),
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        final obj = decodeJsonObject(content);
        if (obj == null) return null;
        return AiCategoryPrediction(
          categoryName: obj['categoria']?.toString().trim(),
          subcategoryName: obj['subcategoria']?.toString().trim(),
          isNewCategory: obj['es_nueva_categoria'] == true,
          isNewSubcategory: obj['es_nueva_subcategoria'] == true,
          iconEmoji: obj['icono']?.toString().trim(),
          reason: obj['razon']?.toString().trim(),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Compatibilidad retroactiva para llamadas que solo solicitan el nombre de categoría.
  Future<String?> predictCategoryFast(
    String product,
    List<dynamic> categories,
  ) async {
    final pred = await predictCategoryAndSubcategory(
      product,
      categories,
      const [],
    );
    return pred?.categoryName;
  }

  /// Extrae una transacción desde un texto pegado de notificación Yape, Plin, BCP, Interbank, BBVA, etc.
  Future<Map<String, dynamic>?> parseBankOrWalletText(
    String pastedText,
    List<dynamic> categories,
    List<dynamic> subcategories,
    List<dynamic> accounts,
  ) async {
    if (pastedText.trim().isEmpty) return null;
    final todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final tree = _buildCategoryTree(categories, subcategories);
    final accountsListStr = accounts.isEmpty
        ? 'No especificadas'
        : accounts.map((a) => (a as dynamic).name.toString()).join(', ');

    final prompt =
        '''
Eres un extractor de notificaciones bancarias y billeteras peruanas (Yape, Plin, BCP, Interbank, BBVA, Scotiabank, Agora, etc.).
Fecha de hoy: $todayIso
Árbol de categorías y subcategorías del usuario:
$tree
Cuentas del usuario: $accountsListStr

Analiza el mensaje pegado y devuelve ÚNICAMENTE este JSON EXACTO (sin markdown):
{
  "tipo": "expense", // "expense" si pagó/yapeó/compró, "income" si recibió dinero/abono, "transfer" si fue transferencia entre cuentas propias
  "monto": 0.00,
  "moneda": "PEN", // "PEN", "USD" o "EUR"
  "descripcion": "Comercio o persona",
  "producto": null,
  "categoria_sugerida": "Categoría más adecuada del árbol o propuesta",
  "subcategoria_sugerida": null,
  "es_nueva_categoria": false,
  "es_nueva_subcategoria": false,
  "cuenta_sugerida": null, // ej. Yape, Plin, BCP según el mensaje y cuentas del usuario
  "fecha": "$todayIso"
}
''';

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/parse-voice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemPrompt': prompt,
              'userMessage': pastedText.trim(),
              'taskType': 'fast_json',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        return decodeJsonObject(content);
      }
    } catch (_) {}
    return null;
  }
}
