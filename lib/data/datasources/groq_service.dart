import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/config/app_config.dart';

/// Servicio que conecta con Groq Cloud (Llama 3.3 70B) para responder
/// preguntas financieras del usuario de forma gratuita y muy rápida.
/// Obtén tu API key gratis en https://console.groq.com
class GroqService {
  static String get _baseUrl => AppConfig.apiBaseUrl;

  static const String _systemPrompt = '''
Eres WalletAI, un asistente financiero personal inteligente integrado en una app de gestión de gastos personal.
Tu rol es ayudar al usuario a entender sus finanzas, dar consejos, analizar datos y responder cualquier pregunta sobre dinero, ahorro y gastos.

Reglas:
- Responde SIEMPRE en español peruano/latinoamericano
- Sé conciso y amigable (máximo 3-4 párrafos cortos)
- Usa emojis con moderación para hacer las respuestas más visuales
- Cuando tengas datos financieros del usuario en el contexto, úsalos para personalizar tu respuesta
- Si el usuario pregunta de presupuestos, ahorros, gastos o ingresos, relaciona la respuesta con sus datos reales
- Si no tienes datos del usuario para una pregunta específica, responde con consejos generales útiles
- No inventes datos que no te han proporcionado
- Los montos están en soles peruanos (S/)''';

  /// Historial de mensajes (rol + contenido) para mantener el contexto de la conversación
  final List<Map<String, String>> _history = [];

  GroqService();

  /// Envía un mensaje al modelo con contexto financiero opcional
  Future<String> sendMessage(
    String userMessage, {
    String? financialContext,
  }) async {
    // Construir el mensaje completo con contexto si está disponible
    final fullMessage = financialContext != null && financialContext.isNotEmpty
        ? '**Datos actuales del usuario:**\n$financialContext\n\n**Pregunta:** $userMessage'
        : userMessage;

    // Agregar el mensaje del usuario al historial
    _history.add({'role': 'user', 'content': fullMessage});

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/parse-voice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemPrompt': _systemPrompt,
              'userMessage': fullMessage,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final assistantMessage =
            data['choices'][0]['message']['content'] as String;

        // Guardar respuesta en historial para contexto futuro
        _history.add({'role': 'assistant', 'content': assistantMessage});

        // Limitar historial a últimos 20 mensajes para no sobrepasar tokens
        if (_history.length > 20) {
          _history.removeRange(0, 2);
        }

        return assistantMessage;
      } else {
        final errorData = jsonDecode(response.body);
        String errorMsg = 'Error desconocido';

        if (errorData['error'] != null) {
          if (errorData['error'] is String) {
            errorMsg = errorData['error'];
          } else if (errorData['error'] is Map) {
            errorMsg = errorData['error']['message'] ?? 'Error desconocido';
          }
        }

        if (response.statusCode == 401) {
          _history.removeLast(); // Revertir mensaje fallido
          return '🔑 API key de Groq configurada en el servidor no es válida o está ausente.';
        } else if (response.statusCode == 429) {
          _history.removeLast();
          return '⏳ Límite de consultas alcanzado. Espera un momento e intenta de nuevo.';
        }

        _history.removeLast();
        return '❌ Error del servidor Groq (${response.statusCode}): $errorMsg';
      }
    } catch (e) {
      _history.removeLast();
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

  /// PROCESAMIENTO VOZ: Analiza un texto dictado por el usuario y extrae información estructurada
  Future<Map<String, dynamic>?> parseVoiceTransaction(
    String rawVoice,
    List<dynamic> categories,
  ) async {
    final categoriesListStr = categories.map((c) => c.name).join(', ');

    final prompt =
        '''
1️⃣ ROL DEL SISTEMA
Actúa como un Asistente Financiero Especializado en Procesamiento de Lenguaje Natural (NLP).
Tu tarea es interpretar un texto dictado por voz por el usuario y extraer los datos para registrar una transacción.

2️⃣ OBJETIVO Y FORMATO DE SALIDA (JSON EXACTO)
Extraer datos y devolver ESTE JSON EXACTO:
{
  "tipo": "expense", // 'expense', 'income' o 'transfer'
  "monto": 0.00, // Detectar el monto numérico
  "descripcion": "cadena del nombre del lugar o detalle general",
  "producto": "cadena del producto específico (opcional, null si no hay un producto claro)",
  "cantidad": 1, // Número de items comprados, por defecto 1 si no se menciona
  "unidad": "UND", // Asignar UND, KG, LTR, GRS, CAJA o MTS. Por defecto UND si no hay unidad clara.
  "categoria_sugerida": "cadena exacta de una de las categorías disponibles"
}

3️⃣ CATEGORÍAS DISPONIBLES PARA ASIGNAR:
$categoriesListStr

4️⃣ REGLAS DE EXTRACCIÓN
- Si el usuario dice "Gasté 20 soles en 2 kilos de pollo en el mercado", debes extraer:
  tipo: "expense"
  monto: 20.00
  descripcion: "Mercado"
  producto: "Pollo"
  cantidad: 2
  unidad: "KG"
  categoria_sugerida: "Alimentación" (u otra afín)
- Si el usuario dice "Me pagaron 1500 de mi sueldo":
  tipo: "income"
  monto: 1500.00
  descripcion: "Sueldo"
  producto: null
  cantidad: 1
  unidad: "UND"
  categoria_sugerida: "Salario" (o afín)
- Si dice "Transferí 50 soles a mi hermano":
  tipo: "transfer"
  monto: 50.00
  descripcion: "Transferencia a hermano"
  producto: null
  cantidad: 1
  unidad: "UND"

5️⃣ RESPUESTA
Solo devuelve JSON válido. No incluyas explicaciones de texto ni bloques de Markdown (```json).

Texto dictado:
''';

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/parse-voice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'systemPrompt': prompt, 'userMessage': rawVoice}),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        return jsonDecode(content) as Map<String, dynamic>?;
      }
    } catch (_) {
      // Si falla, retornar null para caer en logica fallback
    }
    return null;
  }

  /// PREDICCIÓN EN TIEMPO REAL: Analiza el nombre de un producto y sugiere una categoría rápidamente
  Future<String?> predictCategoryFast(
    String product,
    List<dynamic> categories,
  ) async {
    if (product.trim().isEmpty) return null;

    final categoriesListStr = categories.map((c) => c.name).join(', ');
    final prompt =
        '''
Eres un categorizador financiero predictivo ultra-rápido.
El usuario está escribiendo un gasto y necesitas decirle a qué categoría pertenece de acuerdo a su nombre o entidad.

CATEGORÍAS DISPONIBLES:
$categoriesListStr

REGLAS ESTRICTAS:
1. Devuelve SOLAMENTE el nombre EXACTO de UNA de las categorías disponibles.
2. Si tienes dudas, trata de inferirlo por el contexto comercial (Ej. Netflix -> Entretenimiento, Starbucks -> Alimentación, Chifa -> Alimentación).
3. Si es absolutamente imposible deducirlo o es ambiguo, devuelve la palabra: OTRO
4. NUNCA des explicaciones, marcos de código ni comillas. Solo la palabra exacta.
''';

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/parse-voice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'systemPrompt': prompt, 'userMessage': product}),
          )
          .timeout(
            const Duration(seconds: 4),
          ); // Timeout muy corto por ser predictivo

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim();
      }
    } catch (_) {
      // Si falla (timeout o red), retorna null silenciosamente para no arruinar la experiencia
    }
    return null;
  }
}
