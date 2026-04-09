// Utilitários gerais para manipulação de imagens

import '../models/leaf_analysis_model.dart';

/// Retorna a descrição de severidade baseada no percentual de dano.
/// Mantém compatibilidade com o widget de resultado que passa um double.
String damageLabel(double percentage) {
  return severityLabel(_severityFromPercentage(percentage));
}

/// Retorna o rótulo em português para um [SeverityLevel].
String severityLabel(SeverityLevel level) {
  switch (level) {
    case SeverityLevel.low:
      return 'Leve';
    case SeverityLevel.medium:
      return 'Moderado';
    case SeverityLevel.high:
      return 'Severo';
    case SeverityLevel.critical:
      return 'Crítico';
  }
}

SeverityLevel _severityFromPercentage(double percentage) {
  if (percentage <= 10) return SeverityLevel.low;
  if (percentage <= 30) return SeverityLevel.medium;
  if (percentage <= 60) return SeverityLevel.high;
  return SeverityLevel.critical;
}
