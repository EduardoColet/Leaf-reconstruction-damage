import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Nível de severidade do dano foliar.
/// Faixas:
///  - low:      0–10%
///  - medium:  11–30%
///  - high:    31–60%
///  - critical: 61–100%
enum SeverityLevel { low, medium, high, critical }

class LeafAnalysisModel extends Equatable {
  final String id;
  final String imagePath;           // caminho original (referência)
  final Uint8List originalBytes;    // bytes da imagem original
  final Uint8List segmentedBytes;   // bytes da imagem segmentada
  final Uint8List reconstructedBytes; // bytes da imagem com Convex Hull
  final double realArea;            // pixels² — folha visível (sem buracos)
  final double totalArea;           // pixels² — Convex Hull (forma reconstruída)
  final double holeArea;            // pixels² — buracos internos da folha
  final double damagedArea;         // pixels² — dano total (bordas + buracos)
  final double damagePercentage;    // 0.0 a 100.0
  final DateTime analyzedAt;

  const LeafAnalysisModel({
    required this.id,
    required this.imagePath,
    required this.originalBytes,
    required this.segmentedBytes,
    required this.reconstructedBytes,
    required this.realArea,
    required this.totalArea,
    required this.holeArea,
    required this.damagedArea,
    required this.damagePercentage,
    required this.analyzedAt,
  });

  /// Dano somente nas bordas (Convex Hull – folha real – buracos)
  double get edgeDamageArea => (totalArea - realArea - holeArea).clamp(0.0, double.infinity);

  /// Severidade computada a partir do percentual de dano.
  SeverityLevel get severityLevel {
    if (damagePercentage <= 10) return SeverityLevel.low;
    if (damagePercentage <= 30) return SeverityLevel.medium;
    if (damagePercentage <= 60) return SeverityLevel.high;
    return SeverityLevel.critical;
  }

  @override
  List<Object?> get props => [id, damagePercentage, analyzedAt];
}
