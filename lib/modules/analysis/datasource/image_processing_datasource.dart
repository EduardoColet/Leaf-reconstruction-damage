import 'dart:math';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';

// Ponto 2D simples para cálculos geométricos
class _Point {
  final int x;
  final int y;
  const _Point(this.x, this.y);
}

// Interface do datasource de processamento de imagem
abstract class ImageProcessingDatasource {
  /// Executa o pipeline completo de análise foliar.
  /// Recebe [imageBytes] para compatibilidade cross-platform e
  /// [imagePath] para armazenar a referência original no modelo.
  Future<Either<Failure, LeafAnalysisModel>> processImage(
      Uint8List imageBytes, String imagePath);
}

/// Implementação do pipeline de 9 etapas usando o pacote [image] (Dart puro).
class ImageProcessingDatasourceImpl implements ImageProcessingDatasource {
  @override
  Future<Either<Failure, LeafAnalysisModel>> processImage(
      Uint8List imageBytes, String imagePath) async {
    try {
      // ──────────────────────────────────────────────
      // ETAPA 1 — Decodificar bytes da imagem
      // Usa bytes diretamente — compatível com mobile, web e desktop.
      // ──────────────────────────────────────────────
      final original = img.decodeImage(imageBytes);
      if (original == null) {
        return const Left(ImageProcessingFailure('Não foi possível decodificar a imagem'));
      }

      // ──────────────────────────────────────────────
      // ETAPA 2 — Pré-processamento
      // Redimensiona para largura máxima de 800px (mantém proporção)
      // e aplica Gaussian Blur para redução de ruído.
      // ──────────────────────────────────────────────
      final resized = img.copyResize(original, width: 800);
      final blurred = img.gaussianBlur(resized, radius: 2);

      final width = blurred.width;
      final height = blurred.height;

      // ──────────────────────────────────────────────
      // ETAPA 3 — Segmentação da folha
      // Threshold por faixa de verde no espaço HSV +
      // operações morfológicas (closing) para remover ruído.
      // ──────────────────────────────────────────────
      final rawMask = _segmentGreen(blurred, width, height);
      final closedMask = _morphClose(rawMask, width, height, kernelSize: 5);

      // ──────────────────────────────────────────────
      // ETAPA 4 — Detecção do maior contorno (componente)
      // ──────────────────────────────────────────────
      final foregroundPixels = _getLargestComponent(closedMask, width, height);
      if (foregroundPixels.isEmpty) {
        return const Left(
          ImageProcessingFailure(
            'Nenhuma folha detectada. Verifique o fundo e a iluminação.',
          ),
        );
      }

      // Reconstrói máscara apenas com o maior componente
      final finalMask = List.generate(height, (_) => List.filled(width, false));
      for (final p in foregroundPixels) {
        finalMask[p.y][p.x] = true;
      }

      // ──────────────────────────────────────────────
      // ETAPA 4b — Detecção de buracos internos
      // Flood-fill a partir das bordas externas para identificar o fundo
      // alcançável. Pixels de fundo NÃO alcançáveis = buracos dentro da folha.
      // ──────────────────────────────────────────────
      final holeMask = _detectHoles(finalMask, width, height);
      final holeArea = _countTrue(holeMask).toDouble();

      // ──────────────────────────────────────────────
      // ETAPA 5 — Cálculo da área real (pixels da folha segmentada)
      // ──────────────────────────────────────────────
      final realArea = foregroundPixels.length.toDouble();

      // ──────────────────────────────────────────────
      // ETAPA 6 — Reconstrução via Convex Hull
      // Aplica o algoritmo de Graham Scan sobre os pixels
      // de borda da folha para obter o polígono convexo.
      // ──────────────────────────────────────────────
      final boundaryPoints = _getBoundaryPoints(finalMask, width, height);
      final hull = _convexHull(boundaryPoints);

      // ──────────────────────────────────────────────
      // ETAPA 7 — Cálculo da área reconstruída (Convex Hull)
      // ──────────────────────────────────────────────
      final totalArea = _polygonArea(hull);
      if (totalArea <= 0) {
        return const Left(
          ImageProcessingFailure('Área do Convex Hull inválida'),
        );
      }

      // ──────────────────────────────────────────────
      // ETAPA 8 — Estimativa de dano foliar
      // area_dano = area_total - area_real
      // dano_percentual = (area_dano / area_total) * 100
      // ──────────────────────────────────────────────
      final damagedArea = (totalArea - realArea).clamp(0.0, double.infinity);
      final damagePercentage = (damagedArea / totalArea * 100).clamp(0.0, 100.0);

      // ──────────────────────────────────────────────
      // ETAPA 9 — Gerar imagens de resultado como bytes
      // Sem salvar em disco — compatível com web e desktop.
      // ──────────────────────────────────────────────
      final segmentedImg = _buildSegmentedImage(resized, finalMask, width, height);
      final reconstructedImg = _buildReconstructedImage(
          resized, finalMask, holeMask, hull, width, height);

      final id = const Uuid().v4();
      final segmentedBytes = Uint8List.fromList(img.encodePng(segmentedImg));
      final reconstructedBytes = Uint8List.fromList(img.encodePng(reconstructedImg));

      return Right(
        LeafAnalysisModel(
          id: id,
          imagePath: imagePath,
          originalBytes: imageBytes,
          segmentedBytes: segmentedBytes,
          reconstructedBytes: reconstructedBytes,
          realArea: realArea,
          totalArea: totalArea,
          holeArea: holeArea,
          damagedArea: damagedArea,
          damagePercentage: damagePercentage,
          analyzedAt: DateTime.now(),
        ),
      );
    } catch (e) {
      return Left(ImageProcessingFailure('Erro ao processar imagem: $e'));
    }
  }

  // ────────────────────────────────────────────────
  // SEGMENTAÇÃO: threshold de verde no espaço HSV
  // H ∈ [60°, 160°] (cobre amarelo-verde até azul-verde)
  // S > 0.15, V > 0.10
  // ────────────────────────────────────────────────
  List<List<bool>> _segmentGreen(img.Image image, int width, int height) {
    final mask = List.generate(height, (_) => List.filled(width, false));

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble() / 255.0;
        final g = pixel.g.toDouble() / 255.0;
        final b = pixel.b.toDouble() / 255.0;

        final hsv = _rgbToHsv(r, g, b);
        final h = hsv[0]; // 0–360
        final s = hsv[1]; // 0–1
        final v = hsv[2]; // 0–1

        // Faixa de verde-amarelado até verde-azulado
        if (h >= 60 && h <= 160 && s > 0.15 && v > 0.10) {
          mask[y][x] = true;
        }
      }
    }
    return mask;
  }

  // Converte RGB (0–1 cada) para HSV. Retorna [H(0-360), S(0-1), V(0-1)].
  List<double> _rgbToHsv(double r, double g, double b) {
    final maxC = max(r, max(g, b));
    final minC = min(r, min(g, b));
    final delta = maxC - minC;

    double h = 0;
    if (delta > 0) {
      if (maxC == r) {
        h = 60 * (((g - b) / delta) % 6);
      } else if (maxC == g) {
        h = 60 * (((b - r) / delta) + 2);
      } else {
        h = 60 * (((r - g) / delta) + 4);
      }
    }
    if (h < 0) h += 360;

    final s = maxC == 0 ? 0.0 : delta / maxC;
    final v = maxC;

    return [h, s, v];
  }

  // ────────────────────────────────────────────────
  // MORFOLOGIA: Closing = Dilation seguida de Erosion
  // Fecha pequenos buracos na máscara da folha.
  // ────────────────────────────────────────────────
  List<List<bool>> _morphClose(
    List<List<bool>> mask,
    int width,
    int height, {
    int kernelSize = 5,
  }) {
    final dilated = _dilate(mask, width, height, kernelSize);
    return _erode(dilated, width, height, kernelSize);
  }

  List<List<bool>> _dilate(
      List<List<bool>> mask, int width, int height, int k) {
    final half = k ~/ 2;
    final out = List.generate(height, (_) => List.filled(width, false));
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        outer:
        for (int dy = -half; dy <= half; dy++) {
          for (int dx = -half; dx <= half; dx++) {
            final ny = y + dy;
            final nx = x + dx;
            if (ny >= 0 && ny < height && nx >= 0 && nx < width) {
              if (mask[ny][nx]) {
                out[y][x] = true;
                break outer;
              }
            }
          }
        }
      }
    }
    return out;
  }

  List<List<bool>> _erode(
      List<List<bool>> mask, int width, int height, int k) {
    final half = k ~/ 2;
    final out = List.generate(height, (_) => List.filled(width, false));
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        bool allTrue = true;
        outer:
        for (int dy = -half; dy <= half; dy++) {
          for (int dx = -half; dx <= half; dx++) {
            final ny = y + dy;
            final nx = x + dx;
            if (ny < 0 || ny >= height || nx < 0 || nx >= width) {
              allTrue = false;
              break outer;
            }
            if (!mask[ny][nx]) {
              allTrue = false;
              break outer;
            }
          }
        }
        out[y][x] = allTrue;
      }
    }
    return out;
  }

  // ────────────────────────────────────────────────
  // MAIOR COMPONENTE CONEXA (BFS 4-conectividade)
  // Retorna a lista de pixels do maior componente.
  // ────────────────────────────────────────────────
  List<_Point> _getLargestComponent(
      List<List<bool>> mask, int width, int height) {
    final visited = List.generate(height, (_) => List.filled(width, false));
    List<_Point> largest = [];

    const dx = [1, -1, 0, 0];
    const dy = [0, 0, 1, -1];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (mask[y][x] && !visited[y][x]) {
          // BFS
          final component = <_Point>[];
          final queue = <_Point>[_Point(x, y)];
          visited[y][x] = true;

          while (queue.isNotEmpty) {
            final p = queue.removeAt(0);
            component.add(p);

            for (int d = 0; d < 4; d++) {
              final nx = p.x + dx[d];
              final ny = p.y + dy[d];
              if (nx >= 0 &&
                  nx < width &&
                  ny >= 0 &&
                  ny < height &&
                  mask[ny][nx] &&
                  !visited[ny][nx]) {
                visited[ny][nx] = true;
                queue.add(_Point(nx, ny));
              }
            }
          }

          if (component.length > largest.length) {
            largest = component;
          }
        }
      }
    }
    return largest;
  }

  // ────────────────────────────────────────────────
  // PIXELS DE BORDA: foreground com vizinho background
  // ────────────────────────────────────────────────
  List<_Point> _getBoundaryPoints(
      List<List<bool>> mask, int width, int height) {
    final boundary = <_Point>[];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!mask[y][x]) continue;
        // Verifica se tem algum vizinho fora da máscara
        if ((x > 0 && !mask[y][x - 1]) ||
            (x < width - 1 && !mask[y][x + 1]) ||
            (y > 0 && !mask[y - 1][x]) ||
            (y < height - 1 && !mask[y + 1][x])) {
          boundary.add(_Point(x, y));
        }
      }
    }
    return boundary;
  }

  // ────────────────────────────────────────────────
  // CONVEX HULL — algoritmo de Graham Scan
  // Retorna os vértices do casco convexo em ordem anti-horária.
  // ────────────────────────────────────────────────
  List<_Point> _convexHull(List<_Point> points) {
    if (points.length < 3) return points;

    // Ponto mais baixo (maior y em coordenadas de imagem), desempate pelo menor x
    _Point pivot = points.reduce((a, b) =>
        (a.y > b.y) || (a.y == b.y && a.x < b.x) ? a : b);

    // Ordena por ângulo polar em relação ao pivot
    final sorted = List<_Point>.from(points)..sort((a, b) {
      final angleA = atan2(
          (a.y - pivot.y).toDouble(), (a.x - pivot.x).toDouble());
      final angleB = atan2(
          (b.y - pivot.y).toDouble(), (b.x - pivot.x).toDouble());
      if (angleA != angleB) return angleA.compareTo(angleB);
      // Desempate: mais próximo primeiro
      final distA = _dist2(pivot, a);
      final distB = _dist2(pivot, b);
      return distA.compareTo(distB);
    });

    final hull = <_Point>[];
    for (final p in sorted) {
      while (hull.length >= 2) {
        final cross = _cross(hull[hull.length - 2], hull[hull.length - 1], p);
        if (cross <= 0) {
          hull.removeLast();
        } else {
          break;
        }
      }
      hull.add(p);
    }
    return hull;
  }

  // Produto vetorial para orientação
  double _cross(_Point o, _Point a, _Point b) {
    return (a.x - o.x).toDouble() * (b.y - o.y).toDouble() -
        (a.y - o.y).toDouble() * (b.x - o.x).toDouble();
  }

  double _dist2(_Point a, _Point b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return (dx * dx + dy * dy).toDouble();
  }

  // ────────────────────────────────────────────────
  // ÁREA DO POLÍGONO — fórmula do Shoelace (Gauss)
  // ────────────────────────────────────────────────
  double _polygonArea(List<_Point> hull) {
    if (hull.length < 3) return 0;
    double area = 0;
    final n = hull.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += hull[i].x * hull[j].y;
      area -= hull[j].x * hull[i].y;
    }
    return area.abs() / 2.0;
  }

  // ────────────────────────────────────────────────
  // IMAGEM SEGMENTADA: folha sobre fundo branco
  // ────────────────────────────────────────────────
  img.Image _buildSegmentedImage(
    img.Image source,
    List<List<bool>> mask,
    int width,
    int height,
  ) {
    final out = img.Image(width: width, height: height);
    // Fundo branco
    img.fill(out, color: img.ColorRgb8(255, 255, 255));

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (mask[y][x]) {
          out.setPixel(x, y, source.getPixel(x, y));
        }
      }
    }
    return out;
  }

  // ────────────────────────────────────────────────
  // IMAGEM RECONSTRUÍDA:
  //   1. Fundo branco
  //   2. Interior do Convex Hull preenchido com verde claro
  //      (forma original aproximada da folha sem danos)
  //   3. Pixels reais da folha sobrepostos com cor original
  //   4. Buracos internos marcados em laranja
  //   5. Contorno do Convex Hull em verde escuro
  // ────────────────────────────────────────────────
  img.Image _buildReconstructedImage(
    img.Image source,
    List<List<bool>> mask,
    List<List<bool>> holeMask,
    List<_Point> hull,
    int width,
    int height,
  ) {
    final out = img.Image(width: width, height: height);
    img.fill(out, color: img.ColorRgb8(255, 255, 255));

    // 1. Preenche o interior do Convex Hull com verde claro
    final hullInterior = _fillPolygon(hull, width, height);
    final lightGreen = img.ColorRgb8(180, 230, 180);
    for (final p in hullInterior) {
      out.setPixel(p.x, p.y, lightGreen);
    }

    // 2. Sobrepõe os pixels reais da folha com a cor original
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (mask[y][x]) {
          out.setPixel(x, y, source.getPixel(x, y));
        }
      }
    }

    // 3. Marca buracos internos em laranja
    final orange = img.ColorRgb8(255, 140, 0);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (holeMask[y][x]) {
          out.setPixel(x, y, orange);
        }
      }
    }

    // 4. Contorno do Convex Hull em verde escuro
    final darkGreen = img.ColorRgb8(0, 128, 0);
    final n = hull.length;
    for (int i = 0; i < n; i++) {
      final a = hull[i];
      final b = hull[(i + 1) % n];
      _drawLine(out, a.x, a.y, b.x, b.y, darkGreen);
    }
    return out;
  }

  // ────────────────────────────────────────────────
  // DETECÇÃO DE BURACOS INTERNOS
  // Flood-fill a partir de todos os pixels de fundo nas bordas
  // da imagem. Pixels de fundo não alcançáveis = buracos.
  // ────────────────────────────────────────────────
  List<List<bool>> _detectHoles(
      List<List<bool>> mask, int width, int height) {
    final externalBg =
        List.generate(height, (_) => List.filled(width, false));
    final queue = <_Point>[];

    void enqueue(int x, int y) {
      if (!mask[y][x] && !externalBg[y][x]) {
        externalBg[y][x] = true;
        queue.add(_Point(x, y));
      }
    }

    // Sementes nas quatro bordas da imagem
    for (int x = 0; x < width; x++) {
      enqueue(x, 0);
      enqueue(x, height - 1);
    }
    for (int y = 1; y < height - 1; y++) {
      enqueue(0, y);
      enqueue(width - 1, y);
    }

    const dx = [1, -1, 0, 0];
    const dy = [0, 0, 1, -1];

    while (queue.isNotEmpty) {
      final p = queue.removeAt(0);
      for (int d = 0; d < 4; d++) {
        final nx = p.x + dx[d];
        final ny = p.y + dy[d];
        if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
          enqueue(nx, ny);
        }
      }
    }

    // Buracos = fundo não alcançável pelas bordas
    final holeMask =
        List.generate(height, (_) => List.filled(width, false));
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!mask[y][x] && !externalBg[y][x]) {
          holeMask[y][x] = true;
        }
      }
    }
    return holeMask;
  }

  int _countTrue(List<List<bool>> mask) {
    int count = 0;
    for (final row in mask) {
      for (final v in row) {
        if (v) count++;
      }
    }
    return count;
  }

  // ────────────────────────────────────────────────
  // PREENCHIMENTO DE POLÍGONO — algoritmo scanline
  // Retorna todos os pontos dentro do polígono convexo.
  // ────────────────────────────────────────────────
  List<_Point> _fillPolygon(List<_Point> hull, int width, int height) {
    if (hull.length < 3) return [];
    final filled = <_Point>[];

    int minY = hull.map((p) => p.y).reduce(min);
    int maxY = hull.map((p) => p.y).reduce(max);
    minY = minY.clamp(0, height - 1);
    maxY = maxY.clamp(0, height - 1);

    final n = hull.length;
    for (int y = minY; y <= maxY; y++) {
      final intersections = <int>[];
      for (int i = 0; i < n; i++) {
        final a = hull[i];
        final b = hull[(i + 1) % n];
        if ((a.y <= y && b.y > y) || (b.y <= y && a.y > y)) {
          final x = a.x + (y - a.y) * (b.x - a.x) ~/ (b.y - a.y);
          intersections.add(x);
        }
      }
      intersections.sort();
      for (int i = 0; i + 1 < intersections.length; i += 2) {
        final xStart = intersections[i].clamp(0, width - 1);
        final xEnd = intersections[i + 1].clamp(0, width - 1);
        for (int x = xStart; x <= xEnd; x++) {
          filled.add(_Point(x, y));
        }
      }
    }
    return filled;
  }

  // Algoritmo de Bresenham para desenhar linha
  void _drawLine(
      img.Image image, int x0, int y0, int x1, int y1, img.Color color) {
    int dx = (x1 - x0).abs();
    int dy = (y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;

    while (true) {
      if (x0 >= 0 && x0 < image.width && y0 >= 0 && y0 < image.height) {
        // Linha mais grossa (3px)
        for (int t = -1; t <= 1; t++) {
          if (x0 + t >= 0 && x0 + t < image.width) {
            image.setPixel(x0 + t, y0, color);
          }
          if (y0 + t >= 0 && y0 + t < image.height) {
            image.setPixel(x0, y0 + t, color);
          }
        }
      }
      if (x0 == x1 && y0 == y1) break;
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x0 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y0 += sy;
      }
    }
  }
}
