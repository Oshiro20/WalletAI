/// Utilidades para normalización de texto en búsquedas y conversión de montos.
class TextSearchHelper {
  TextSearchHelper._();

  static const Map<String, String> _diacritics = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
  };

  /// Convierte a minúsculas, elimina tildes/diacríticos y recorta espacios.
  static String normalize(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < lower.length; i++) {
      final ch = lower[i];
      buffer.write(_diacritics[ch] ?? ch);
    }
    return buffer.toString();
  }

  /// Divide una consulta en tokens normalizados (limpiando signos de puntuación).
  static List<String> tokenize(String query) {
    final norm = normalize(query).replaceAll(RegExp(r'[¿?¡!,;:"()\[\]{}]'), ' ');
    if (norm.isEmpty) return const [];
    return norm
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'^\.+|\.+$'), ''))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  /// Retorna true si todos los tokens de búsqueda aparecen en alguno de los campos.
  static bool matchesAllTokens(List<String> tokens, Iterable<String?> fields) {
    if (tokens.isEmpty) return true;
    final combined = normalize(
      fields.where((f) => f != null && f.trim().isNotEmpty).join(' '),
    );
    if (combined.isEmpty) return false;
    return tokens.every((token) => combined.contains(token));
  }

  /// Convierte un monto en [currency] a soles peruanos (PEN) usando [rates] base PEN.
  static double convertToPen(
    double amount,
    String? currency,
    Map<String, double> rates,
  ) {
    if (currency == null || currency == 'PEN') return amount;
    final rate = rates[currency];
    if (rate == null || rate == 0) return amount;
    return amount / rate;
  }

  /// Retorna el símbolo de moneda legible.
  static String currencySymbol(String? currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'PEN':
      case null:
        return 'S/';
      default:
        return '$currency ';
    }
  }
}

