// ignore_for_file: avoid_print
void main() {
  final lines = [
    'MAYORISTA DON PEDRITO EIRL',
    'Via Colectora Nro 11 Urb. Santa Elena',
    'BOLETA DE VENTA ELECTRÃ“NICA',
    'Cliente',
    'Fecha EmisiÃ³n',
    'HuÃ¡nuco- HuÃ¡nuco - Amarills',
    'R.U.C. NÂ° 20601130930',
    'Cant. U.M',
    'BE02-00019854',
    '14/02/2026',
    'POCO X6 Pro 5G',
    'VENTA MOSTRADOR',
    'DescnpciÃ³n',
    '1.0 UNI MONFER BLANQUIAZUL.5',
    'Inporte Total S/',
    'Son: CINCO Y 90/100 SOLES',
    'Hash: XslHeikql SewTUmGWnoFqlHBXZeN=-',
    'Hora: 16: 58:14',
    'Importe',
    '5.90'
  ];

  bool inItemsSection = false;
  const headerMarkers = ['cant', 'cantidad', 'descripcion', 'descripciÃ³n', 'detalle', 'producto', 'descnpciÃ³n'];
  const endMarkers = ['total', 'subtotal', 'importe', 'son:', 'vendedor', 'cajero', 'openpay', 'visa', 'mastercard'];

  final skipPatterns = RegExp(
    r'^(\d+\s*@|\d+\s*x)|\bRUC\b|www\.|^\d{6,}|^[A-Z]\d{2,3}-\d+|POCO X|Venta mostrador|Cliente|Fecha|DNI|Hora:|Ticket|Cajero',
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
      print('Entered items section after: $line');
      continue;
    }

    if (inItemsSection && endMarkers.any((m) => lower.startsWith(m) || lower == m)) {
      print('Exited items section at: $line');
      break;
    }

    if (inItemsSection) {
      print('Checking line: $line');
      if (!skipPatterns.hasMatch(line) && line.length > 4 && !RegExp(r'^\d+[\.,]\d{2}$').hasMatch(line)) {
        final strippedLine = line.replaceFirst(quantityStripPattern, '').trim();
        print('  Stripped line: $strippedLine');
        if (strippedLine.isNotEmpty && strippedLine.length >= 3) {
           candidates.add(strippedLine);
        }
      } else {
        print('  Skipped line: $line');
        print('  skipPattern: ${skipPatterns.hasMatch(line)}');
        print('  length: ${line.length > 4}');
        print('  isPrice: ${RegExp(r"^\d+[\.,]\d{2}$").hasMatch(line)}');
      }
    }
  }

  print('Candidates: $candidates');
}

