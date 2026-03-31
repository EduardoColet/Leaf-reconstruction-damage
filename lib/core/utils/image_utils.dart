// Utilitários gerais para manipulação de imagens

/// Retorna a descrição de severidade baseada no percentual de dano
String damageLabel(double percentage) {
  if (percentage <= 10) return 'Leve';
  if (percentage <= 30) return 'Moderado';
  if (percentage <= 60) return 'Severo';
  return 'Crítico';
}
