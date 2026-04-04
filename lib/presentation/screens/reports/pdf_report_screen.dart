import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';

/// Servicio para generar el reporte PDF mensual
class PdfReportService {
  /// Genera el PDF y retorna los bytes
  static Future<Uint8List> generateMonthlyReport({
    required DateTime month,
    required List<Transaction> transactions,
    required List<Category> categories,
    required List<Account> accounts,
    required Map<String, double> expensesByCategory,
    required Map<String, double> incomeByCategory,
    required double totalExpense,
    required double totalIncome,
  }) async {
    final pdf = pw.Document();
    final monthLabel = DateFormat('MMMM yyyy', 'es').format(month);
    final balance = totalIncome - totalExpense;
    final now = DateTime.now();

    // Helper: get category name
    String catName(String? id) {
      if (id == null) return 'Sin categoría';
      return categories.where((c) => c.id == id).firstOrNull?.name ?? id;
    }

    // Helper: get account name
    String accName(String? id) {
      if (id == null) return 'Sin cuenta';
      return accounts.where((a) => a.id == id).firstOrNull?.name ?? id;
    }

    // Color helpers
    final primaryColor = PdfColor.fromHex('6750A4');
    final redColor = PdfColor.fromHex('B00020');
    final greenColor = PdfColor.fromHex('1B5E20');
    final greyLight = PdfColor.fromHex('F5F5F5');
    final greyDark = PdfColor.fromHex('757575');

    // Sort expenses by category
    final sortedExpenses = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REPORTE FINANCIERO',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.Text(
                      monthLabel.toUpperCase(),
                      style: pw.TextStyle(fontSize: 14, color: greyDark),
                    ),
                  ],
                ),
                pw.Text(
                  'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
                  style: pw.TextStyle(fontSize: 9, color: greyDark),
                ),
              ],
            ),
            pw.Divider(color: primaryColor, thickness: 2),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (ctx) => [
          // ── Summary Cards ──
          pw.Row(
            children: [
              _pdfCard(
                'INGRESOS',
                'S/ ${totalIncome.toStringAsFixed(2)}',
                greenColor,
              ),
              pw.SizedBox(width: 12),
              _pdfCard(
                'GASTOS',
                'S/ ${totalExpense.toStringAsFixed(2)}',
                redColor,
              ),
              pw.SizedBox(width: 12),
              _pdfCard(
                'BALANCE',
                'S/ ${balance.toStringAsFixed(2)}',
                balance >= 0 ? greenColor : redColor,
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Expenses by Category ──
          if (sortedExpenses.isNotEmpty) ...[
            pw.Text(
              'GASTOS POR CATEGORÍA',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryColor),
                  children: [
                    _pdfCell('Categoría', isHeader: true),
                    _pdfCell('Monto', isHeader: true),
                    _pdfCell('% del Total', isHeader: true),
                  ],
                ),
                // Rows
                ...sortedExpenses.map((e) {
                  final pct = totalExpense > 0
                      ? e.value / totalExpense * 100
                      : 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: sortedExpenses.indexOf(e) % 2 == 0
                          ? PdfColors.white
                          : greyLight,
                    ),
                    children: [
                      _pdfCell(catName(e.key)),
                      _pdfCell('S/ ${e.value.toStringAsFixed(2)}'),
                      _pdfCell('${pct.toStringAsFixed(1)}%'),
                    ],
                  );
                }),
                // Total row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: greyLight),
                  children: [
                    _pdfCell('TOTAL', bold: true),
                    _pdfCell(
                      'S/ ${totalExpense.toStringAsFixed(2)}',
                      bold: true,
                    ),
                    _pdfCell('100%', bold: true),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // ── Transaction List ──
          pw.Text(
            'DETALLE DE TRANSACCIONES',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: primaryColor),
                children: [
                  _pdfCell('Fecha', isHeader: true),
                  _pdfCell('Descripción', isHeader: true),
                  _pdfCell('Categoría', isHeader: true),
                  _pdfCell('Cuenta', isHeader: true),
                  _pdfCell('Monto', isHeader: true),
                ],
              ),
              ...transactions.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                final isExpense = t.type == 'expense';
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i % 2 == 0 ? PdfColors.white : greyLight,
                  ),
                  children: [
                    _pdfCell(DateFormat('dd/MM').format(t.date)),
                    _pdfCell(t.description ?? '-', maxLines: 1),
                    _pdfCell(catName(t.categoryId)),
                    _pdfCell(accName(t.accountId)),
                    _pdfCell(
                      '${isExpense ? '-' : '+'}S/ ${t.amount.toStringAsFixed(2)}',
                      color: isExpense ? redColor : greenColor,
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Footer ──
          pw.Divider(color: greyDark),
          pw.Text(
            'Reporte generado por Aplicativo Gastos • ${DateFormat('dd/MM/yyyy').format(now)}',
            style: pw.TextStyle(fontSize: 9, color: greyDark),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1.5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromHex('757575'),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    bool bold = false,
    PdfColor? color,
    int? maxLines,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        maxLines: maxLines,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: (isHeader || bold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : (color ?? PdfColors.black),
        ),
      ),
    );
  }
}

// ─── PDF Report Screen ────────────────────────────────────────────────────────

class PdfReportScreen extends ConsumerStatefulWidget {
  const PdfReportScreen({super.key});

  @override
  ConsumerState<PdfReportScreen> createState() => _PdfReportScreenState();
}

class _PdfReportScreenState extends ConsumerState<PdfReportScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reporte PDF Mensual')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month selector
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecciona el mes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month - 1,
                            );
                          }),
                        ),
                        Text(
                          DateFormat('MMMM yyyy', 'es').format(_selectedMonth),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                            );
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // What's included
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'El reporte incluye:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...[
                      '📊 Resumen de ingresos, gastos y balance',
                      '🗂️ Gastos desglosados por categoría',
                      '📋 Lista completa de transacciones',
                      '💳 Cuenta utilizada en cada transacción',
                    ].map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              item.substring(0, 2),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.substring(3),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAndPreview,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _isGenerating ? 'Generando...' : 'Generar y Compartir PDF',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGenerating ? null : _generateAndPrint,
                icon: const Icon(Icons.print),
                label: const Text(
                  'Vista Previa / Imprimir',
                  style: TextStyle(fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndPreview() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _buildPdf();
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'reporte_${DateFormat('yyyy_MM').format(_selectedMonth)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateAndPrint() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _buildPdf();
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    final transactionsDao = ref.read(transactionsDaoProvider);
    final categoriesDao = ref.read(categoriesDaoProvider);
    final accountsDao = ref.read(accountsDaoProvider);

    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    final transactions = await transactionsDao.getTransactionsByDateRange(
      start,
      end,
    );
    final categories = await categoriesDao.getAllCategories();
    final accounts = await accountsDao.getAllAccounts();
    final expensesByCategory = await transactionsDao.getExpensesByCategory(
      start,
      end,
    );

    // Income by category
    final incomeByCategory = <String, double>{};
    for (final t in transactions) {
      if (t.type == 'income' && t.categoryId != null) {
        incomeByCategory[t.categoryId!] =
            (incomeByCategory[t.categoryId!] ?? 0) + t.amount;
      }
    }

    final totalExpense = transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);
    final totalIncome = transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);

    // Sort transactions by date desc
    transactions.sort((a, b) => b.date.compareTo(a.date));

    return PdfReportService.generateMonthlyReport(
      month: _selectedMonth,
      transactions: transactions,
      categories: categories,
      accounts: accounts,
      expensesByCategory: expensesByCategory,
      incomeByCategory: incomeByCategory,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
    );
  }
}
