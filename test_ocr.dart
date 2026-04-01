void main() {
  final text = """MAYORISTA DON PEDRITO EIRL
Via Colectora Nro 11 Urb. Santa Elena
Cliente
BOLETA DE VENTA ELECTRONICA
Fecha Emision
Huanuco - Huanuco - Amarilis
R.U.C. No 20601130930
Cant. U.M
BE02-00019854
POCO X6 Pro 5G
14/02/2026
VENTA MOSTRADOR
Deseripcion
1 0 UNI MONFER BLANQUIAZUL *5
importe Total S
Son: CINCO Y 90/100 SOLES
Hash: XsIHeikql SewTUmGwnoFqHBX2EN=
Hora: 16:58:14
Importe
S.90
Consulte su Comprobante de Pago Electronico en
https://donpedrito.sivedata.com/buscar
S.90""";

  // Simulate internal parser behavior
  final lines = text.split('\n');
  bool inItemsSection = false;
  const headerMarkers = ['cant', 'cantidad', 'descripcion', 'descripción', 'detalle', 'producto'];
  const endMarkers = ['total', 'subtotal', 'importe', 'son:', 'vendedor', 'cajero', 'openpay', 'visa', 'mastercard'];
  final skipPatterns = RegExp(
    r'^(\d+\s*@|\d+\s*x)|\bRUC\b|www\.|^\d{6,}|^[a-zA-Z0-9]{2,4}-\d+|^\d{2}/\d{2}/\d{2,4}|Venta mostrador|Cliente|Fecha|DNI|Hora:|Ticket|Cajero|Des[ce]r.*pci[oó]n|Cant\b',
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
    final lower = line.toLowerCase();

    if (!inItemsSection && headerMarkers.any((m) => lower.contains(m))) {
      inItemsSection = true;
      continue;
    }
    if (inItemsSection && endMarkers.any((m) => lower.startsWith(m) || lower == m)) {
      break;
    }

    if (inItemsSection) {
      if (!skipPatterns.hasMatch(line) && line.length > 3 && !RegExp(r'^\d+[\.,]\d{2}$').hasMatch(line)) {
        final strippedLine = line.replaceFirst(quantityStripPattern, '').trim();
        if (strippedLine.isNotEmpty && strippedLine.length >= 3) {
           candidates.add(strippedLine);
        }
      }
    }
  }

  String? bestCandidate;
  double bestScore = -1.0;

  for (var candidate in candidates) {
    String clean = candidate.replaceAll(RegExp(r'\d{6,}'), '').trim();
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length < 3) continue;

    int letterCount = clean.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    int numCount = clean.replaceAll(RegExp(r'[^0-9]'), '').length;
    
    double score = letterCount.toDouble();
    if (numCount > letterCount && numCount > 5) score -= (numCount * 0.5);
    
    if (clean.toUpperCase().contains('MONFER') || clean.toUpperCase().contains('UNI')) {
        score -= 20.0;
    }

    if (score > bestScore) {
      bestScore = score;
      bestCandidate = clean;
    }
  }

  print("Mejor Candidato: \ (Puntaje: \)");
}
