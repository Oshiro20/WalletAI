// ignore_for_file: avoid_print

void main() {
  // 1. Logic copied from ReceiptScannerService for testing
  ScannedReceipt? parse(String text) {
    double? amount;
    DateTime? date;
    String? merchant;

    final lines = text.split('\n');
    
    // Merchant: First non-empty line
    for (var line in lines) {
      if (line.trim().isNotEmpty) {
        merchant = line.trim();
        break;
      }
    }

    // Date Regex
    // 1. Numeric: 14/02/2026 or 14-02-2026
    final dateRegexNumeric = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b');
    var dateMatch = dateRegexNumeric.firstMatch(text);
    
    if (dateMatch != null) {
      try {
        int day = int.parse(dateMatch.group(1)!);
        int month = int.parse(dateMatch.group(2)!);
        int year = int.parse(dateMatch.group(3)!);
        if (year < 100) year += 2000;
        date = DateTime(year, month, day);
      } catch (e) { print('Date parse error numeric: $e'); }
    } else {
       // 2. Text: "FEBR 14 2026" or "14 FEB 2026"
       // Map Spanish months
       final months = {
         'ENE': 1, 'FEB': 2, 'MAR': 3, 'ABR': 4, 'MAY': 5, 'JUN': 6,
         'JUL': 7, 'AGO': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DIC': 12,
         'FEBR': 2, 'SET': 9 // Variants
       };
       
       // Regex for text month: (FEB|FEBR) (\d{1,2}) (\d{4}) or (\d{1,2}) (FEB) (\d{4})
       final dateRegexText = RegExp(r'\b([A-Z]{3,4})\s+(\d{1,2})\s+(\d{4})\b', caseSensitive: false);
       final matchText = dateRegexText.firstMatch(text);
       
       if (matchText != null) {
         String monthStr = matchText.group(1)!.toUpperCase();
         // Handle Month-Day-Year or Day-Month-Year? 
         // Dollarcity: FEBR 14 2026 -> Month Day Year
         
         if (months.containsKey(monthStr)) {
            int month = months[monthStr]!;
            int day = int.parse(matchText.group(2)!);
            int year = int.parse(matchText.group(3)!);
            date = DateTime(year, month, day);
         }
       }
    }

    // Amount Regex
    final amountRegex = RegExp(r'[0-9]+[.,][0-9]{2}');
    
    for (var line in lines) {
      String lowerLine = line.toLowerCase();
      // Expanded keywords based on receipts
      if (lowerLine.contains('total') || 
          lowerLine.contains('importe') || 
          lowerLine.contains('pagar') || 
          lowerLine.contains('suma')) { // removed S/ to avoid false positives in lines with just S/
            
        final matches = amountRegex.allMatches(line);
        for (var match in matches) {
          String matchStr = match.group(0)!.replaceAll(',', '.');
          double? val = double.tryParse(matchStr);
          if (val != null) {
            // Priority to "Total" lines
            if (amount == null || val > amount) {
              amount = val;
            }
          }
        }
      }
    }

    // Fallback: Just get the largest number that looks like money if no explicit "Total" found
    // Or if found amount is small/wrong
    if (amount == null) {
      final allMatches = amountRegex.allMatches(text);
      if (allMatches.isNotEmpty) {
         // Look at last few numbers (totals usually at bottom)
         for (var m in allMatches) {
            String s = m.group(0)!.replaceAll(',', '.');
            double? v = double.tryParse(s);
            if (v != null && (amount == null || v > amount)) amount = v;
         }
      }
    }

    return ScannedReceipt(amount: amount, date: date, merchant: merchant, rawText: text);
  }


  // --- TEST CASES ---

  // Image 1: Don Pedrito
  final text1 = """
  MAYORISTA DON PEDRITO EIRL
  R.U.C. N 20601130930
  BOLETA DE VENTA ELECTRONICA
  Fecha Emision 14/02/2026
  Cliente
  VENTA MOSTRADOR
  Descripcion
  1.0 UNI MONFER BLANQUIAZUL*5 5.90
  Importe Total S/ 5.90
  Son: CINCO Y 90/100 SOLES
  """;

  // Image 2: Dollarcity (Approximation)
  final text2 = """
  Dollarcity
  SOLANA COMERCIAL S.A.C.
  AV. SANTO TORIBIO N.143
  26 Y 27 URBANIZACI??N SANTA ELENA
  VISA 
  FEBR 14 2026 17:09
  TOTAL S/ 18.64
  SUBTOTAL 18.64
  """;

  print("--- Test 1 (Don Pedrito) ---");
  print(parse(text1));

  print("\n--- Test 2 (Dollarcity) ---");
  print(parse(text2));
}

class ScannedReceipt {
  final double? amount;
  final DateTime? date;
  final String? merchant;
  final String rawText;
  ScannedReceipt({this.amount, this.date, this.merchant, required this.rawText});
  @override
  String toString() => 'Merchant: $merchant, Date: $date, Amount: $amount';
}

