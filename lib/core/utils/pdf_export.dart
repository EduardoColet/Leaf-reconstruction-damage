import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/leaf_analysis_model.dart';
import 'image_utils.dart';

/// Gera um PDF com o resultado da análise foliar e abre o diálogo
/// de compartilhamento/salvamento do sistema.
Future<void> exportAnalysisPdf(
  LeafAnalysisModel result, {
  double? pxPerCm,
}) async {
  final pdf = pw.Document();

  final originalImage = pw.MemoryImage(result.originalBytes);
  final segmentedImage = pw.MemoryImage(result.segmentedBytes);
  final reconstructedImage = pw.MemoryImage(result.reconstructedBytes);

  final severity = damageLabel(result.damagePercentage);
  final date =
      '${result.analyzedAt.day.toString().padLeft(2, '0')}/'
      '${result.analyzedAt.month.toString().padLeft(2, '0')}/'
      '${result.analyzedAt.year}  '
      '${result.analyzedAt.hour.toString().padLeft(2, '0')}:'
      '${result.analyzedAt.minute.toString().padLeft(2, '0')}';

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => _buildHeader(date),
      build: (context) => [
        // Percentual de dano
        _buildDamageSection(result.damagePercentage, severity),
        pw.SizedBox(height: 20),

        // Métricas
        _buildMetricsTable(result, pxPerCm: pxPerCm),
        pw.SizedBox(height: 20),

        // Imagens
        _buildImageSection('Imagem Original', originalImage),
        pw.SizedBox(height: 12),
        _buildImageSection('Folha Segmentada', segmentedImage),
        pw.SizedBox(height: 12),
        _buildImageSection('Folha Reconstruída (Convex Hull)', reconstructedImage),
      ],
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
        ),
      ),
    ),
  );

  final bytes = await pdf.save();

  await Printing.sharePdf(
    bytes: bytes,
    filename: 'leafscope_analise_${result.id}.pdf',
  );
}

pw.Widget _buildHeader(String date) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.green, width: 2)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'LeafScope — Relatório de Análise Foliar',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
        ),
        pw.Text(date, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ],
    ),
  );
}

pw.Widget _buildDamageSection(double percentage, String severity) {
  final color = _severityPdfColor(percentage);
  return pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: color, width: 1.5),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      children: [
        pw.Text(
          '${percentage.toStringAsFixed(1)}%',
          style: pw.TextStyle(fontSize: 48, fontWeight: pw.FontWeight.bold, color: color),
        ),
        pw.SizedBox(height: 4),
        pw.Text('de dano foliar', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Text(
            severity.toUpperCase(),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildMetricsTable(LeafAnalysisModel result, {double? pxPerCm}) {
  String fmt(double pixels) {
    if (pxPerCm != null) {
      final cm2 = pixels / (pxPerCm * pxPerCm);
      return '${cm2.toStringAsFixed(2)} cm²';
    }
    if (pixels >= 1000000) return '${(pixels / 1000000).toStringAsFixed(2)} Mpx²';
    if (pixels >= 1000) return '${(pixels / 1000).toStringAsFixed(1)} kpx²';
    return '${pixels.toStringAsFixed(0)} px²';
  }

  final rows = <List<String>>[
    ['Área total (Convex Hull)', fmt(result.totalArea)],
    ['Área real da folha', fmt(result.realArea)],
    ['Dano nas bordas', fmt(result.edgeDamageArea)],
    ['Buracos internos', fmt(result.holeArea)],
    ['Área danificada total', fmt(result.damagedArea)],
    ['Percentual de dano', '${result.damagePercentage.toStringAsFixed(1)}%'],
  ];

  return pw.TableHelper.fromTextArray(
    headers: ['Métrica', 'Valor'],
    data: rows,
    border: pw.TableBorder.all(color: PdfColors.grey300),
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.green50),
    cellStyle: const pw.TextStyle(fontSize: 11),
    cellAlignment: pw.Alignment.centerLeft,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  );
}

pw.Widget _buildImageSection(String title, pw.MemoryImage image) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Center(
        child: pw.Image(image, width: 340, fit: pw.BoxFit.contain),
      ),
    ],
  );
}

PdfColor _severityPdfColor(double percentage) {
  if (percentage <= 10) return PdfColors.green;
  if (percentage <= 30) return PdfColors.amber;
  if (percentage <= 60) return PdfColors.orange;
  return PdfColors.red;
}
