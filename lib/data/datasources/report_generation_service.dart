import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../database/drift_database.dart';

class ReportGenerationService {
  /// Genera y permite compartir un PDF de reporte financiero.
  static Future<void> generateAndSharePdf({
    required List<Transaction> transactions,
    required List<Category> categories,
    required String monthYear,
    required double totalIncome,
    required double totalExpense,
    required String baseCurrency,
  }) async {
    final pdf = pw.Document();

    // Intentamos cargar una fuente de Google Fonts para un aspecto profesional
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      symbol: '$baseCurrency ',
      decimalDigits: 2,
    );

    // Agrupamos las transacciones por tipo para el gráfico de barras o resumen
    final incomes = transactions.where((t) => t.type == 'income').toList();
    final expenses = transactions.where((t) => t.type == 'expense').toList();

    // Calculamos balance
    final balance = totalIncome - totalExpense;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            _buildHeader(monthYear),
            pw.SizedBox(height: 20),
            _buildSummary(
              totalIncome,
              totalExpense,
              balance,
              currencyFormat,
              fontBold,
            ),
            pw.SizedBox(height: 30),
            if (expenses.isNotEmpty) ...[
              pw.Text(
                'Gastos por Categoría',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildCategoryPieChart(expenses, categories, totalExpense, font),
              pw.SizedBox(height: 30),
              pw.Text(
                'Detalle de Gastos',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red800,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildTransactionTable(expenses, dateFormat, currencyFormat),
              pw.SizedBox(height: 30),
            ],
            if (incomes.isNotEmpty) ...[
              pw.Text(
                'Detalle de Ingresos',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildTransactionTable(incomes, dateFormat, currencyFormat),
            ],
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount} - Generado por WalletAI',
              style: const pw.TextStyle(color: PdfColors.grey),
            ),
          );
        },
      ),
    );

    // Generamos los bytes
    final Uint8List bytes = await pdf.save();

    // Compartimos usando printing
    final fileName = 'Reporte_${monthYear.replaceAll(' ', '_')}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  static pw.Widget _buildHeader(String monthYear) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'WalletAI',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.Text(
              'Reporte Financiero',
              style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Text(
          monthYear,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _buildSummary(
    double income,
    double expense,
    double balance,
    NumberFormat currencyFormat,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryBox(
            'Ingresos',
            income,
            PdfColors.green700,
            currencyFormat,
            fontBold,
          ),
          _buildSummaryBox(
            'Gastos',
            expense,
            PdfColors.red700,
            currencyFormat,
            fontBold,
          ),
          _buildSummaryBox(
            'Balance',
            balance,
            balance >= 0 ? PdfColors.blue700 : PdfColors.red700,
            currencyFormat,
            fontBold,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryBox(
    String title,
    double amount,
    PdfColor color,
    NumberFormat currencyFormat,
    pw.Font fontBold,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          currencyFormat.format(amount),
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTransactionTable(
    List<Transaction> transactions,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    final headers = ['Fecha', 'Descripción', 'Monto'];

    final data = transactions.map((t) {
      final desc = t.productName ?? t.description ?? 'Sin descripción';
      return [dateFormat.format(t.date), desc, currencyFormat.format(t.amount)];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
    );
  }

  static pw.Widget _buildCategoryPieChart(
    List<Transaction> expenses,
    List<Category> categories,
    double totalExpense,
    pw.Font font,
  ) {
    if (totalExpense <= 0) return pw.SizedBox();

    // Sumar gastos por categoría
    final Map<String, double> categorySums = {};
    for (final e in expenses) {
      if (e.categoryId != null) {
        categorySums[e.categoryId!] =
            (categorySums[e.categoryId!] ?? 0) + e.amount;
      }
    }

    // Ordenar de mayor a menor y tomar el top 5
    var sortedEntries = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    var topEntries = sortedEntries.take(5).toList();
    var otherSum = sortedEntries
        .skip(5)
        .fold<double>(0, (sum, item) => sum + item.value);

    // Colores para el gráfico
    final colors = [
      PdfColors.blue400,
      PdfColors.red400,
      PdfColors.green400,
      PdfColors.orange400,
      PdfColors.purple400,
    ];

    int colorIndex = 0;

    // Construir tabla de leyenda (emulando un gráfico circular mediante una gráfica de barras o tabla)
    // El paquete pdf nativo no tiene PieChart nativo, así que hacemos un Chart de barras horizontal muy elegante

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          for (final entry in topEntries)
            _buildBarRow(
              categories.where((c) => c.id == entry.key).firstOrNull?.name ??
                  'Otros',
              entry.value,
              totalExpense,
              colors[colorIndex++ % colors.length],
            ),
          if (otherSum > 0)
            _buildBarRow(
              'Demás Categorías',
              otherSum,
              totalExpense,
              PdfColors.grey400,
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildBarRow(
    String label,
    double value,
    double total,
    PdfColor color,
  ) {
    final double pct = value / total;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 12),
              maxLines: 1,
            ),
          ),
          pw.Expanded(
            child: pw.Stack(
              children: [
                pw.Container(
                  height: 12,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                ),
                pw.Container(
                  width: 120 * pct, // Fijo el width base
                  height: 12,
                  decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 8),
          pw.SizedBox(
            width: 40,
            child: pw.Text(
              '${(pct * 100).toStringAsFixed(1)}%',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );
  }
}
