import 'dart:math';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../../core/models/leaf_analysis_model.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/pdf_export.dart';

class AnalysisResultWidget extends StatefulWidget {
  final LeafAnalysisModel result;

  const AnalysisResultWidget({super.key, required this.result});

  @override
  State<AnalysisResultWidget> createState() => _AnalysisResultWidgetState();
}

class _AnalysisResultWidgetState extends State<AnalysisResultWidget> {
  // ── Calibração de escala ──────────────────────────────
  // O usuário marca dois pontos na imagem original e informa
  // a distância real em cm para converter px² em cm².
  Offset? _pointA;
  Offset? _pointB;
  final _distanceController = TextEditingController();
  double? _pxPerCm; // pixels por cm (calculado após confirmação)

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  /// Converte área em px² para cm² usando o fator de escala
  String _formatArea(double pixels, {bool forcePx = false}) {
    if (!forcePx && _pxPerCm != null) {
      final cm2 = pixels / (_pxPerCm! * _pxPerCm!);
      return '${cm2.toStringAsFixed(2)} cm²';
    }
    if (pixels >= 1000000) return '${(pixels / 1000000).toStringAsFixed(2)} Mpx²';
    if (pixels >= 1000) return '${(pixels / 1000).toStringAsFixed(1)} kpx²';
    return '${pixels.toStringAsFixed(0)} px²';
  }

  /// Distância em pixels entre os dois pontos marcados
  double get _markedDistancePx {
    if (_pointA == null || _pointB == null) return 0;
    final dx = _pointA!.dx - _pointB!.dx;
    final dy = _pointA!.dy - _pointB!.dy;
    return sqrt(dx * dx + dy * dy);
  }

  void _confirmScale() {
    final cm = double.tryParse(_distanceController.text.replaceAll(',', '.'));
    final distPx = _markedDistancePx;
    if (cm != null && cm > 0 && distPx > 0) {
      setState(() {
        _pxPerCm = distPx / cm;
      });
      Navigator.of(context).pop();
    }
  }

  void _showScaleDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar escala'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distância marcada: ${_markedDistancePx.toStringAsFixed(0)} px',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _distanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Distância real (cm)',
                suffixText: 'cm',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _confirmScale,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Indicador de dano ──────────────────────
          _DamageIndicatorCard(percentage: widget.result.damagePercentage),
          const SizedBox(height: 16),

          // ── Visualização das 3 imagens ─────────────
          _ImageComparisonRow(result: widget.result),
          const SizedBox(height: 16),

          // ── Calibração de escala ───────────────────
          _ScaleCalibrationCard(
            imageBytes: widget.result.originalBytes,
            pointA: _pointA,
            pointB: _pointB,
            pxPerCm: _pxPerCm,
            onImageSizeKnown: (_) {},
            onTap: (offset) {
              setState(() {
                if (_pointA == null) {
                  _pointA = offset;
                } else if (_pointB == null) {
                  _pointB = offset;
                  // Abre diálogo automaticamente quando os dois pontos estão marcados
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showScaleDialog();
                  });
                } else {
                  // Reinicia a calibração
                  _pointA = offset;
                  _pointB = null;
                  _pxPerCm = null;
                }
              });
            },
            onReset: () => setState(() {
              _pointA = null;
              _pointB = null;
              _pxPerCm = null;
              _distanceController.clear();
            }),
          ),
          const SizedBox(height: 16),

          // ── Métricas detalhadas ────────────────────
          _MetricsCard(
            result: widget.result,
            formatArea: _formatArea,
            pxPerCm: _pxPerCm,
          ),
          const SizedBox(height: 24),

          // ── Botões de ação ─────────────────────────
          ElevatedButton.icon(
            onPressed: () => exportAnalysisPdf(
              widget.result,
              pxPerCm: _pxPerCm,
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Exportar PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Modular.to.navigate('/'),
            icon: const Icon(Icons.home),
            label: const Text('Voltar ao Início'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Modular.to.pushNamed('/capture'),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Nova Análise'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
              side: const BorderSide(color: Color(0xFF4CAF50)),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Card com percentual de dano e indicador de severidade
// ──────────────────────────────────────────────────────
class _DamageIndicatorCard extends StatelessWidget {
  final double percentage;

  const _DamageIndicatorCard({required this.percentage});

  Color get _color {
    if (percentage <= 10) return const Color(0xFF4CAF50);
    if (percentage <= 30) return const Color(0xFFFFC107);
    if (percentage <= 60) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: _color,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'de dano foliar',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _color, width: 1.5),
              ),
              child: Text(
                damageLabel(percentage).toUpperCase(),
                style: TextStyle(
                  color: _color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(_color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Visualização das 3 imagens empilhadas em largura cheia
// (mesmo tamanho da imagem da calibração de escala)
// ──────────────────────────────────────────────────────
class _ImageComparisonRow extends StatelessWidget {
  final LeafAnalysisModel result;

  const _ImageComparisonRow({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visualização',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            // Legenda da imagem reconstruída
            Row(
              children: [
                _LegendDot(color: const Color(0xFFB4E6B4), label: 'Área reconstruída'),
                const SizedBox(width: 12),
                _LegendDot(color: const Color(0xFFFF8C00), label: 'Buracos'),
                const SizedBox(width: 12),
                _LegendDot(color: const Color(0xFF008000), label: 'Contorno Hull'),
              ],
            ),
            const SizedBox(height: 12),
            _ImageTile(label: 'Original', bytes: result.originalBytes),
            const SizedBox(height: 16),
            _ImageTile(label: 'Segmentada', bytes: result.segmentedBytes),
            const SizedBox(height: 16),
            _ImageTile(label: 'Reconstruída', bytes: result.reconstructedBytes),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String label;
  final Uint8List bytes;

  const _ImageTile({required this.label, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displayWidth = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                width: displayWidth,
                fit: BoxFit.fitWidth,
                errorBuilder: (context, error, stack) => Container(
                  width: displayWidth,
                  height: displayWidth * 0.75,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────
// Card de calibração de escala
// O usuário toca dois pontos na imagem e informa a distância
// real em cm para que as áreas sejam exibidas em cm².
// ──────────────────────────────────────────────────────
class _ScaleCalibrationCard extends StatelessWidget {
  final Uint8List imageBytes;
  final Offset? pointA;
  final Offset? pointB;
  final double? pxPerCm;
  final ValueChanged<Size> onImageSizeKnown;
  final ValueChanged<Offset> onTap;
  final VoidCallback onReset;

  const _ScaleCalibrationCard({
    required this.imageBytes,
    required this.pointA,
    required this.pointB,
    required this.pxPerCm,
    required this.onImageSizeKnown,
    required this.onTap,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.straighten, size: 18, color: Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Calibração de escala (opcional)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (pointA != null)
                  IconButton(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Reiniciar calibração',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              pxPerCm != null
                  ? 'Escala definida: ${pxPerCm!.toStringAsFixed(1)} px/cm  →  áreas em cm²'
                  : pointA == null
                      ? 'Toque em dois pontos de distância conhecida na imagem.'
                      : pointB == null
                          ? 'Toque no segundo ponto.'
                          : 'Confirme a distância no diálogo.',
              style: TextStyle(
                fontSize: 12,
                color: pxPerCm != null ? const Color(0xFF4CAF50) : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            // Imagem interativa com marcadores
            LayoutBuilder(
              builder: (context, constraints) {
                final displayWidth = constraints.maxWidth;
                return GestureDetector(
                  onTapUp: (details) => onTap(details.localPosition),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          imageBytes,
                          width: displayWidth,
                          fit: BoxFit.fitWidth,
                          frameBuilder: (ctx, child, frame, _) {
                            if (frame != null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final box = ctx.findRenderObject() as RenderBox?;
                                if (box != null) onImageSizeKnown(box.size);
                              });
                            }
                            return child;
                          },
                        ),
                      ),
                      if (pointA != null)
                        _PointMarker(offset: pointA!, label: 'A', color: Colors.blue),
                      if (pointB != null)
                        _PointMarker(offset: pointB!, label: 'B', color: Colors.red),
                      if (pointA != null && pointB != null)
                        CustomPaint(
                          size: Size(displayWidth, displayWidth * 0.75),
                          painter: _LinePainter(pointA!, pointB!),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PointMarker extends StatelessWidget {
  final Offset offset;
  final String label;
  final Color color;

  const _PointMarker({required this.offset, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx - 12,
      top: offset.dy - 12,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final Offset a;
  final Offset b;
  const _LinePainter(this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(a, b, paint);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.a != a || old.b != b;
}

// ──────────────────────────────────────────────────────
// Card com métricas numéricas detalhadas
// ──────────────────────────────────────────────────────
class _MetricsCard extends StatelessWidget {
  final LeafAnalysisModel result;
  final String Function(double, {bool forcePx}) formatArea;
  final double? pxPerCm;

  const _MetricsCard({
    required this.result,
    required this.formatArea,
    required this.pxPerCm,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Métricas',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (pxPerCm != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4CAF50)),
                    ),
                    child: const Text(
                      'cm²',
                      style: TextStyle(fontSize: 11, color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _MetricRow(
              icon: Icons.crop_free,
              iconColor: const Color(0xFF4CAF50),
              label: 'Área total (Convex Hull)',
              value: formatArea(result.totalArea),
            ),
            const Divider(height: 16),
            _MetricRow(
              icon: Icons.eco,
              iconColor: Colors.green,
              label: 'Área real da folha',
              value: formatArea(result.realArea),
            ),
            const Divider(height: 16),
            _MetricRow(
              icon: Icons.healing,
              iconColor: Colors.orange,
              label: 'Dano nas bordas',
              value: formatArea(result.edgeDamageArea),
            ),
            const Divider(height: 16),
            _MetricRow(
              icon: Icons.circle_outlined,
              iconColor: const Color(0xFFFF8C00),
              label: 'Buracos internos',
              value: formatArea(result.holeArea),
            ),
            const Divider(height: 16),
            _MetricRow(
              icon: Icons.warning_amber,
              iconColor: Colors.red,
              label: 'Área danificada total',
              value: formatArea(result.damagedArea),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _MetricRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
