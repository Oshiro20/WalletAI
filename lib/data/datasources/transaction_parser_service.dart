import '../database/drift_database.dart';

class ParsedTransactionData {
  final double? amount;
  final String? type; // 'expense' or 'income'
  final String? categoryId;
  final String? subcategoryId;
  final String? accountId;
  final String? description;

  ParsedTransactionData({
    this.amount,
    this.type,
    this.categoryId,
    this.subcategoryId,
    this.accountId,
    this.description,
  });
}

// ─────────────────────────────────────────────────────────────
// DICCIONARIO DE SUBCATEGORÍAS — ordena primero las más específicas
// ─────────────────────────────────────────────────────────────
const Map<String, List<String>> _subcategoryKeywords = {
  // ── ALIMENTACIÓN ───────────────────────────────────────────
  'sub_mercado': [
    // frutas
    'mandarina', 'naranja', 'manzana', 'pera', 'platano', 'platanos', 'uva',
    'uvas', 'fresa', 'fresas', 'papaya', 'mango', 'piña', 'pina', 'melon',
    'sandia', 'limon', 'limons', 'maracuya', 'chirimoya', 'lucuma',
    // verduras
    'brocoli', 'zanahoria', 'cebolla', 'ajo', 'tomate', 'tomates', 'lechuga',
    'pepino', 'espinaca', 'espinacas', 'apio', 'pimiento', 'choclo', 'elote',
    // tubérculos
    'papa', 'papas', 'camote', 'yuca', 'betarraga',
    // granos y secos
    'arroz', 'frijoles', 'frijol', 'lentejas', 'avena', 'quinua', 'menestras',
    'menestra', 'lenteja', 'garbanzo', 'garbanzos',
    // lácteos
    'leche', 'queso', 'yogurt', 'mantequilla', 'crema de leche',
    // proteínas crudas
    'huevo', 'huevos', 'plancha de huevo', 'pollo', 'carne', 'atun',
    'filete', 'higado', 'molida', 'salmon',
    // panadería básica
    'pan', 'pan de molde', 'pan de yema',
    // abarrotes
    'aceite', 'sal', 'azucar', 'harina', 'maizena', 'fideos', 'pasta',
    'sopa', 'sopa de sobre', 'cubito', 'mayonesa', 'ketchup', 'mostaza',
    'vinagre', 'salsa de soja', 'mermelada', 'manteca',
    // bebidas para casa
    'agua de mesa', 'jugo de caja', 'agua san luis', 'agua cielo',
    // supermercados
    'mercado', 'supermercado', 'plaza vea', 'tottus', 'metro', 'wong',
    'vivanda', 'makro', 'bodega', 'tienda', 'compras', 'viveres', 'abarrotes',
    'viveres de casa',
  ],
  'sub_restaurantes': [
    'cena', 'almuerzo', 'desayuno', 'menu', 'plato', 'polleria', 'chifa',
    'anticucho', 'ceviche', 'lomo', 'arroz con', 'salchipapa', 'papa a la',
    'causa', 'aji de gallina', 'pollo a la brasa', 'parrilla', 'bbq',
    'hamburgesa', 'hamburguesa', 'hot dog', 'sandwich', 'tacos', 'burritos',
    'sushi', 'pasta', 'pizza', 'cafe', 'cafeteria', 'jugo', 'chicharron',
    'tiradito', 'sopas', 'caldo', 'restaurant', 'restaurante', 'comida',
    'almuerzo ejecutivo', 'menu del dia', 'plato del dia', 'segundo',
  ],
  'sub_delivery': [
    'rappi', 'pedidos ya', 'pedidosya', 'ifood', 'uber eats', 'ubereats',
    'delivery', 'a domicilio', 'por delivery', 'orden delivery',
  ],
  'sub_snacks': [
    'chocolate', 'helado', 'chifles', 'papitas', 'doritos', 'pringles',
    'galleta', 'galletas', 'galleta dulce', 'golosina', 'caramelo',
    'brownie', 'muffin', 'donut', 'dona', 'churro', 'palomitas',
    'gaseosa', 'coca cola', 'inca kola', 'sprite', 'fanta', 'pepsi',
    'energy drink', 'red bull', 'snack', 'antojo', 'capricho',
  ],

  // ── TRANSPORTE ─────────────────────────────────────────────
  'sub_taxi': [
    'uber', 'indriver', 'beat', 'cabify', 'taxi', 'mototaxi', 'moto taxi',
    'taxi peru', 'easy taxi',
  ],
  'sub_publico': [
    'bus', 'micro', 'combi', 'metropolitano', 'metro', 'tren', 'pasaje',
    'transporte publico', 'custer', 'colectivo', 'rapidito',
  ],
  'sub_gasolina': [
    'gasolina', 'combustible', 'grifo', 'gasolinera', 'petroleo',
    'gas natural', 'gnv', 'glp',
  ],
  'sub_estacionamiento': [
    'estacionamiento', 'parking', 'playa de estacionamiento', 'peaje',
    'autopista', 'via expresa',
  ],

  // ── ENTRETENIMIENTO ────────────────────────────────────────
  'sub_streaming': [
    'netflix', 'disney', 'hbo', 'amazon prime', 'youtube premium',
    'crunchyroll', 'paramount', 'apple tv', 'dazn', 'star plus',
    'streaming', 'suscripcion', 'suscripción',
  ],
  'sub_salidas': [
    'cine', 'pelicula', 'teatro', 'concierto', 'discoteca', 'karaoke',
    'bowling', 'parque', 'circo', 'espectaculo', 'evento', 'show',
  ],
  'sub_juegos': [
    'playstation', 'xbox', 'steam', 'nintendo', 'videojuego', 'videojuegos',
    'juego', 'juegos', 'gaming', 'app de pago', 'in-app', 'robux', 'v-bucks',
    'fortnite', 'minecraft', 'lol', 'dota', 'battle pass',
  ],
  'sub_libros_revistas': [
    'libro', 'libros', 'revista', 'revistas', 'kindle', 'audible',
    'periodico', 'comic', 'manga', 'novela',
  ],

  // ── SALUD ──────────────────────────────────────────────────
  'sub_farmacia': [
    'pastilla', 'pastillas', 'medicina', 'medicamento', 'vitamina',
    'suplemento', 'antibiotico', 'ampolla', 'jeringa', 'venda', 'alcohol',
    'inkafarma', 'mifarma', 'botica', 'farmacia',
  ],
  'sub_citas': [
    'doctor', 'medico', 'cita', 'consulta', 'clinica', 'hospital',
    'dentista', 'odontologo', 'psicologo', 'nutricionista', 'traumatologo',
    'urgencia', 'emergencia', 'analisis', 'radiografia', 'ecografia',
  ],
  'sub_gym': [
    'gym', 'gimnasio', 'smart fit', 'sportlife', 'bodytech', 'mensualidad gym',
    'membresia gym',
  ],

  // ── CUIDADO PERSONAL ───────────────────────────────────────
  'sub_peluqueria': [
    'peluqueria', 'barberia', 'corte', 'corte de cabello', 'tinte',
    'alisado', 'peinado', 'barba', 'depilacion',
  ],
  'sub_higiene': [
    'shampoo', 'jabon', 'crema', 'desodorante', 'perfume', 'pasta dental',
    'cepillo dental', 'enjuague', 'rasuradora', 'gillette', 'colgate',
    'listerine', 'head shoulders', 'protector solar', 'bloqueador',
    'toalla higienica', 'pañal',
  ],
  'sub_estetica': [
    'manicure', 'pedicure', 'spa', 'masaje', 'maquillaje', 'base', 'labial',
    'mascara', 'sombra', 'rubor', 'rimmel', 'cejas', 'pestañas',
  ],

  // ── ROPA ───────────────────────────────────────────────────
  'sub_ropa': [
    'camisa', 'camiseta', 'polo', 'pantalon', 'vestido', 'falda', 'blusa',
    'chompa', 'casaca', 'abrigo', 'ropa interior', 'pijama', 'camison',
    'bermuda', 'ropa',
  ],
  'sub_calzado': [
    'zapatos', 'zapatillas', 'sandalias', 'botas', 'tenis', 'mocasines',
    'crocs', 'chancletas', 'calzado',
  ],
  'sub_ropa_deportiva': [
    'licra', 'shorts', 'polo dry fit', 'medias deportivas', 'ropa deportiva',
    'traje de bano', 'traje de baño', 'conjunto deportivo',
  ],
  'sub_accesorios_moda': [
    'correa', 'cinturon', 'cartera', 'billetera', 'bolso', 'mochila',
    'lentes de sol', 'aretes', 'pulsera', 'collar', 'anillo', 'reloj',
    'gorro', 'sombrero', 'bufanda', 'guantes', 'accesorio',
  ],

  // ── HOGAR ──────────────────────────────────────────────────
  'sub_servicios_hogar': [
    'luz', 'agua', 'gas', 'internet', 'cable', 'alquiler', 'condominio',
    'mantenimiento de edificio', 'renta', 'departamento', 'casa',
  ],
  'sub_limpieza_hogar': [
    'detergente', 'lejia', 'escoba', 'trapeador', 'limpiatodo', 'esponja',
    'bolsas de basura', 'accesorio de limpieza', 'limpieza', 'desinfectante',
    'jabon lavavajillas', 'lavavajillas', 'suavizante', 'ambientador',
  ],
  'sub_mantenimiento_hogar': [
    'gasfitero', 'electricista', 'plomero', 'pintura', 'reparacion',
    'mantenimiento', 'instalacion', 'techado', 'grifo roto', 'arreglo',
  ],
  'sub_electrodomesticos': [
    'licuadora', 'plancha', 'ventilador', 'tostadora', 'cafetera',
    'microondas', 'hervidora', 'arrocera', 'electrodomestico', 'foco',
    'lampara', 'enchufe', 'extension electrica', 'bateria', 'pila',
  ],
  'sub_decoracion': [
    'cuadro', 'cojin', 'lampara decorativa', 'planta', 'florero', 'espejo',
    'cortina', 'alfombra', 'decoracion', 'mueble', 'silla', 'mesa',
    'estante', 'armario',
  ],

  // ── DEPORTE/FITNESS ────────────────────────────────────────
  'sub_membresia_gym': [
    'mensualidad gym', 'membresia smart fit', 'membresia bodytech',
    'mensualidad gimnasio', 'membresia gimnasio',
  ],
  'sub_equipo_deportivo': [
    'balon', 'pelota', 'raqueta', 'guantes de box', 'guantes', 'bicicleta',
    'casco', 'implementos deportivos', 'equipo deportivo',
  ],
  'sub_clases': [
    'clase de yoga', 'pilates', 'natacion', 'futbol', 'clase de baile',
    'zumba', 'crossfit', 'clase de', 'tenis', 'clase',
  ],
  'sub_nutricion_deportiva': [
    'proteina', 'creatina', 'suplemento deportivo', 'bcaa', 'pre workout',
    'pre-workout', 'whey', 'masa muscular',
  ],

  // ── VEHÍCULO ───────────────────────────────────────────────
  'sub_lavado_auto': [
    'lavado de auto', 'lavado de carro', 'car wash', 'lavado vehiculo',
    'limpieza de auto',
  ],
  'sub_mecanica': [
    'mecanico', 'taller', 'repuesto', 'cambio de aceite', 'frenos',
    'llanta', 'bateria de auto', 'revision tecnica', 'soat', 'seguro vehicular',
    'reparacion auto', 'alineamiento', 'balanceo',
  ],
  'sub_peajes': [
    'peaje', 'autopista', 'via expresa', 'pase de peaje', 'telepeaje',
  ],

  // ── VIAJES ─────────────────────────────────────────────────
  'sub_pasajes': [
    'pasaje de avion', 'vuelo', 'boleto aereo', 'bus interprovincial',
    'cruz del sur', 'oltursa', 'movil tours', 'ormeño', 'pasaje de bus',
    'aeropuerto', 'latam', 'sky airline', 'avianca',
  ],
  'sub_hospedaje': [
    'hotel', 'hostal', 'airbnb', 'alojamiento', 'hospedaje', 'motel',
    'habitacion', 'suite',
  ],
  'sub_tours': [
    'tour', 'excursion', 'actividad turistica', 'entrada a', 'museum',
    'museo', 'parque nacional', 'agencia de viajes',
  ],

  // ── REGALOS/DONACIONES ─────────────────────────────────────
  'sub_regalos': [
    'regalo', 'regalos', 'cumpleanos', 'cumpleaños', 'navidad', 'flores',
    'bouquet', 'arreglo floral', 'chocolates de regalo', 'torta',
    'festejo', 'presente',
  ],
  'sub_donaciones': [
    'donacion', 'donacion', 'colecta', 'propina', 'limosna', 'iglesia',
    'ofrenda', 'diezmo',
  ],

  // ── MASCOTAS ───────────────────────────────────────────────
  'sub_alimento_mascota': [
    'alimento para perro', 'alimento para gato', 'pedigree', 'purina',
    'royal canin', 'croquetas', 'comida para mascota',
  ],
  'sub_veterinario': [
    'veterinario', 'veterinaria', 'vacuna de perro', 'vacuna de gato',
    'desparasitacion', 'consulta veterinaria',
  ],
  'sub_accesorios_mascota': [
    'correa de perro', 'collar de perro', 'juguete de mascota', 'arena para gato',
    'shampoo de mascota', 'accesorio mascota',
  ],

  // ── PAREJA ─────────────────────────────────────────────────
  'sub_salida_romantica': [
    'cena romantica', 'cena para dos', 'restaurante con angie', 'salida con angie',
    'date', 'cita romantica', 'cita con mi amor', 'aniversario cena',
    'san valentin', 'cita con', 'salimos juntos', 'fuimos juntos',
  ],
  'sub_regalos_pareja': [
    'regalo para angie', 'regalo para mi amor', 'detalle para angie',
    'sorpresa para', 'flores para angie', 'perfume para angie',
  ],
  'sub_plan_especial': [
    'san valentin', 'aniversario', 'luna de miel', 'viaje con angie',
    'viaje con mi amor', 'plan especial',
  ],
  'sub_detalles_dia': [
    'cafe con angie', 'helado con angie', 'algo rico con', 'paseo con',
    'paseo con angie', 'paseo con mi amor',
  ],

  // ── INVERSIONES ────────────────────────────────────────────
  'sub_fondo_ahorro': [
    'fondo de ahorro', 'deposito a ahorros', 'transferencia a ahorros',
    'fondo mutuo', 'fondos mutuos',
  ],
  'sub_acciones': [
    'acciones', 'bolsa de valores', 'trading', 'broker', 'etf',
    'buy acciones', 'compra de acciones',
  ],
  'sub_cripto': [
    'bitcoin', 'ethereum', 'cripto', 'criptomoneda', 'btc', 'eth',
    'usdt', 'binance', 'coinbase', 'crypto',
  ],
};

// ─────────────────────────────────────────────────────────────
// DICCIONARIO DE CATEGORÍAS (fallback si no hay subcategoría)
// ─────────────────────────────────────────────────────────────
const Map<String, List<String>> _categoryKeywords = {
  'cat_alimentacion': [
    'comer', 'hambre', 'alimento', 'alimentacion', 'alimentación', 'comida',
    'mercado', 'supermercado',
  ],
  'cat_transporte': [
    'viaje', 'movilidad', 'transporte', 'movilizarme', 'movilizarse',
  ],
  'cat_salud': ['salud', 'enfermedad', 'dolor', 'malestar'],
  'cat_entretenimiento': ['entretenimiento', 'diversion', 'ocio', 'pasatiempo'],
  'cat_educacion': [
    'educacion', 'educación', 'estudio', 'curso', 'clase', 'colegio',
    'universidad', 'libro', 'utiles', 'cuaderno', 'colegiatura', 'materiales',
    'udemy', 'coursera', 'platzi', 'plataforma educativa',
  ],
  'cat_ropa': [
    'ropa', 'zapatos', 'zapatillas', 'polo', 'pantalon', 'camisa', 'vestido',
    'falda', 'chompa', 'casaca', 'saga', 'ripley', 'oechsle', 'zara', 'hm',
    'short', 'interior', 'accesorio de moda', 'bolso', 'correa',
  ],
  'cat_cuidado_personal': [
    'peluqueria', 'barberia', 'corte', 'cabello', 'shampoo', 'jabon de baño',
    'crema', 'desodorante', 'perfume', 'maquillaje', 'manicure', 'pedicure',
    'spa', 'pasta dental', 'cuidado personal',
  ],
  'cat_trabajo': [
    'trabajo', 'oficina', 'impresion', 'herramienta de trabajo',
    'material de oficina', 'lapicero', 'cuaderno de trabajo',
  ],
  'cat_mascotas': [
    'mascota', 'perro', 'gato', 'veterinario', 'veterinaria',
    'alimento para mascota',
  ],
  'cat_familia': [
    'familia', 'franz', 'arlet', 'milagros', 'mama', 'madre', 'papa', 'padre',
    'hermano', 'hermana', 'tio', 'tia', 'abuelo', 'abuela',
  ],
  'cat_pareja': [
    'angie', 'pareja', 'novia', 'novio', 'mi amor', 'amor', 'enamorada',
    'enamorado', 'con ella', 'juntos', 'cita romantica', 'salida romantica',
    'para angie',
  ],
  'cat_alojamiento': [
    'alquiler', 'renta', 'luz', 'agua', 'internet', 'cable',
    'mantenimiento', 'condominio', 'departamento', 'casa',
    'limpieza hogar', 'detergente', 'escoba', 'trapeador',
  ],
  'cat_antojos': [
    'antojo', 'capricho', 'impulso', 'golosina', 'dulce',
  ],
  'cat_servicios_digitales': [
    'internet movil', 'plan celular', 'recarga celular', 'spotify',
    'youtube music', 'google one', 'icloud', 'dropbox', 'plan de datos',
    'plan postpago',
  ],
  'cat_viajes': [
    'viaje', 'viajar', 'vacaciones', 'tour', 'hospedaje', 'hotel',
    'vuelo', 'pasaje de avion', 'bus interprovincial',
  ],
  'cat_vehiculo': [
    'auto', 'carro', 'vehiculo', 'mecanico', 'taller', 'soat', 'peaje',
    'lavado de auto', 'gasolina',
  ],
  'cat_regalos': [
    'regalo', 'regalos', 'cumpleanos', 'navidad', 'donacion', 'propina',
    'flores', 'torta de cumpleaños',
  ],
  'cat_deporte': [
    'deporte', 'fitness', 'gym', 'gimnasio', 'ejercicio', 'entrenar',
    'entrenamiento', 'nadar', 'correr', 'futbol', 'basquet', 'voley',
  ],
  'cat_inversiones': [
    'inversion', 'inversiones', 'acciones', 'bolsa', 'cripto', 'bitcoin',
    'fondo mutuo', 'trading', 'broker',
  ],
  'cat_otro_gasto': [
    'otro', 'otros', 'pendiente', 'por clasificar', 'sin categoria',
  ],
};

// ─────────────────────────────────────────────────────────────
// Mapeo explícito sub → categoría padre (para fallback sin BD)
// ─────────────────────────────────────────────────────────────
const Map<String, String> _subToCategory = {
  'sub_mercado': 'cat_alimentacion',
  'sub_restaurantes': 'cat_alimentacion',
  'sub_delivery': 'cat_alimentacion',
  'sub_snacks': 'cat_antojos',
  'sub_taxi': 'cat_transporte',
  'sub_publico': 'cat_transporte',
  'sub_gasolina': 'cat_transporte',
  'sub_estacionamiento': 'cat_transporte',
  'sub_streaming': 'cat_entretenimiento',
  'sub_salidas': 'cat_entretenimiento',
  'sub_juegos': 'cat_entretenimiento',
  'sub_libros_revistas': 'cat_entretenimiento',
  'sub_farmacia': 'cat_salud',
  'sub_citas': 'cat_salud',
  'sub_gym': 'cat_salud',
  'sub_peluqueria': 'cat_cuidado_personal',
  'sub_higiene': 'cat_cuidado_personal',
  'sub_estetica': 'cat_cuidado_personal',
  'sub_ropa': 'cat_ropa',
  'sub_calzado': 'cat_ropa',
  'sub_ropa_deportiva': 'cat_ropa',
  'sub_accesorios_moda': 'cat_ropa',
  'sub_servicios_hogar': 'cat_alojamiento',
  'sub_limpieza_hogar': 'cat_alojamiento',
  'sub_mantenimiento_hogar': 'cat_alojamiento',
  'sub_electrodomesticos': 'cat_alojamiento',
  'sub_decoracion': 'cat_alojamiento',
  'sub_membresia_gym': 'cat_deporte',
  'sub_equipo_deportivo': 'cat_deporte',
  'sub_clases': 'cat_deporte',
  'sub_nutricion_deportiva': 'cat_deporte',
  'sub_lavado_auto': 'cat_vehiculo',
  'sub_mecanica': 'cat_vehiculo',
  'sub_peajes': 'cat_vehiculo',
  'sub_pasajes': 'cat_viajes',
  'sub_hospedaje': 'cat_viajes',
  'sub_tours': 'cat_viajes',
  'sub_regalos': 'cat_regalos',
  'sub_donaciones': 'cat_regalos',
  'sub_alimento_mascota': 'cat_mascotas',
  'sub_veterinario': 'cat_mascotas',
  'sub_accesorios_mascota': 'cat_mascotas',
  'sub_salida_romantica': 'cat_pareja',
  'sub_regalos_pareja': 'cat_pareja',
  'sub_plan_especial': 'cat_pareja',
  'sub_detalles_dia': 'cat_pareja',
  'sub_fondo_ahorro': 'cat_inversiones',
  'sub_acciones': 'cat_inversiones',
  'sub_cripto': 'cat_inversiones',
};

String _normalize(String text) {
  const accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
    'ä': 'a', 'ë': 'e', 'ï': 'i', 'ö': 'o', 'ü': 'u',
    'à': 'a', 'è': 'e', 'ì': 'i', 'ò': 'o', 'ù': 'u',
    'ñ': 'n',
  };
  String result = text.toLowerCase();
  accents.forEach((accent, replacement) {
    result = result.replaceAll(accent, replacement);
  });
  return result;
}

class TransactionParserService {

  ParsedTransactionData parse(
    String text,
    List<Category> categories,
    List<Account> accounts, {
    List<Subcategory> subcategories = const [],
  }) {
    final lowerText = _normalize(text);

    // 1. Detectar tipo
    String type = 'expense';
    if (lowerText.contains('ingreso') ||
        lowerText.contains('cobre') ||
        lowerText.contains('recibi') ||
        lowerText.contains('gane') ||
        lowerText.contains('me pagaron') ||
        lowerText.contains('cobré') ||
        lowerText.contains('recibí') ||
        lowerText.contains('me depositaron')) {
      type = 'income';
    }

    // 2. Extraer monto
    final amountRegex = RegExp(r'(\d+[.,]?\d*)');
    final match = amountRegex.firstMatch(text);
    double? amount;
    if (match != null) {
      String amountStr = match.group(1)!.replaceAll(',', '.');
      amount = double.tryParse(amountStr);
    }

    // 3. Detectar cuenta
    String? accountId;
    final accountTriggers = [
      'en mi cuenta ', 'de mi cuenta ', 'con mi ', 'usando mi ',
      'desde mi ', 'con ', 'vía ', 'via ', 'usando ', 'desde ', 'por ',
    ];

    final sortedAccounts = List<Account>.from(accounts)
      ..sort((a, b) => b.name.length.compareTo(a.name.length));

    for (final trigger in accountTriggers) {
      final normalizedTrigger = _normalize(trigger);
      final triggerIdx = lowerText.indexOf(normalizedTrigger);
      if (triggerIdx != -1) {
        final afterTrigger =
            lowerText.substring(triggerIdx + normalizedTrigger.length);
        for (var acc in sortedAccounts) {
          final normalizedAccName = _normalize(acc.name);
          if (afterTrigger.startsWith(normalizedAccName)) {
            accountId = acc.id;
            break;
          }
        }
        if (accountId != null) break;
      }
    }

    if (accountId == null) {
      for (var acc in sortedAccounts) {
        final normalizedAccName = _normalize(acc.name);
        if (lowerText.contains(normalizedAccName)) {
          accountId = acc.id;
          break;
        }
      }
    }

    // 4. Detectar subcategoría (diccionario built-in)
    String? categoryId;
    String? subcategoryId;

    for (final entry in _subcategoryKeywords.entries) {
      final subId = entry.key;
      final keywords = entry.value;
      // Ordenar keywords por longitud desc para preferir frases más específicas
      final sorted = [...keywords]..sort((a, b) => b.length.compareTo(a.length));
      for (final keyword in sorted) {
        if (lowerText.contains(_normalize(keyword))) {
          subcategoryId = subId;
          final matchedSub =
              subcategories.where((s) => s.id == subId).firstOrNull;
          if (matchedSub != null) {
            categoryId = matchedSub.categoryId;
          } else {
            categoryId = _subToCategory[subId];
          }
          break;
        }
      }
      if (subcategoryId != null) break;
    }

    // 4b. Fallback: nombre de subcategoría en texto
    if (subcategoryId == null && subcategories.isNotEmpty) {
      final sortedSubs = List<Subcategory>.from(subcategories)
        ..sort((a, b) => b.name.length.compareTo(a.name.length));
      for (var sub in sortedSubs) {
        if (lowerText.contains(_normalize(sub.name))) {
          subcategoryId = sub.id;
          categoryId = sub.categoryId;
          break;
        }
      }
    }

    // 4c. Fallback: categoría por keywords
    if (categoryId == null) {
      for (final entry in _categoryKeywords.entries) {
        final catId = entry.key;
        final keywords = entry.value;
        final sorted = [...keywords]
          ..sort((a, b) => b.length.compareTo(a.length));
        for (final keyword in sorted) {
          if (lowerText.contains(_normalize(keyword))) {
            categoryId = catId;
            break;
          }
        }
        if (categoryId != null) break;
      }
    }

    // 4d. Fallback: nombre de categoría en texto
    if (categoryId == null) {
      final sortedCategories = List<Category>.from(categories)
        ..sort((a, b) => b.name.length.compareTo(a.name.length));
      for (var cat in sortedCategories) {
        if (lowerText.contains(_normalize(cat.name))) {
          categoryId = cat.id;
          break;
        }
        if (cat.aliases != null && cat.aliases!.isNotEmpty) {
          final aliasList = cat.aliases!
              .split(',')
              .map((a) => _normalize(a.trim()))
              .where((a) => a.isNotEmpty);
          for (final alias in aliasList) {
            if (lowerText.contains(alias)) {
              categoryId = cat.id;
              break;
            }
          }
          if (categoryId != null) break;
        }
      }
    }

    return ParsedTransactionData(
      amount: amount,
      type: type,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      accountId: accountId,
      description: _extractDescription(text, accounts),
    );
  }

  /// Extrae descripción limpia del texto de audio.
  /// Elimina: monto+moneda, palabras de tipo (gasto/compré...), conectores, 
  /// método de pago ("con Yape", "via BCP") y nombres de cuentas.
  /// Resultado: solo el producto/concepto (ej: "Plancha de huevo").
  String _extractDescription(String text, List<Account> accounts) {
    String result = text;

    // 1. Eliminar monto con unidad monetaria (ej: "20 soles", "S/. 15", "$ 10")
    result = result.replaceAll(
      RegExp(
        r'\b\d+[.,]?\d*\s*(soles?|sol|pen|s\/\.?|d[oó]lares?|usd|\$|€|euros?)?\b',
        caseSensitive: false,
      ),
      '',
    );

    // 2. Eliminar palabra de tipo al inicio del texto
    result = result.replaceAll(
      RegExp(
        r'^\s*(gast[eé]|gasto(\s+de|\s+un[a]?)?|compr[eé]|pagu[eé]|compra(\s+de|\s+un[a]?)?|recib[ií]|cobr[eé]|ingreso(\s+de)?|me\s+pagaron|me\s+depositaron)\b\s*',
        caseSensitive: false,
      ),
      '',
    );

    // 3. Eliminar preposición de inicio sobrante (de/en/por/para/un/una)
    result = result.replaceAll(
      RegExp(r'^\s*(de|en|por|para|un[a]?)\s+', caseSensitive: false),
      '',
    );

    // 4. Cortar en el primer trigger de pago y eliminar el resto
    //    Ej: "Plancha de huevo con Yape" → "Plancha de huevo"
    final paymentCutRegex = RegExp(
      r'\s+(con|vía|via|usando|pagando\s+con|pagué\s+con|pagado\s+con|en\s+yape|en\s+bcp|en\s+plin)\s+\S.*$',
      caseSensitive: false,
    );
    result = result.replaceAll(paymentCutRegex, '');

    // 5. Eliminar nombres de cuentas conocidas
    for (final acc in accounts) {
      result = result.replaceAll(
        RegExp(r'\b' + RegExp.escape(acc.name) + r'\b', caseSensitive: false),
        '',
      );
    }

    // 6. Eliminar "en" colgante al final (bug anterior: "Mandarina en")
    result = result.replaceAll(
      RegExp(r'\s+(en|de|con|y|al?)\s*$', caseSensitive: false),
      '',
    );

    // 7. Limpiar espacios múltiples y capitalizar
    result = result.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (result.isEmpty) return text;

    return result.substring(0, 1).toUpperCase() + result.substring(1);
  }
}
