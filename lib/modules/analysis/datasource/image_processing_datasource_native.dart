import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';
import 'image_processing_datasource_base.dart';

/// Implementação do pipeline usando `opencv_dart` (bindings nativos do OpenCV4).
///
/// Disponível apenas em plataformas com `dart:io` e suporte a FFI.
class ImageProcessingDatasourceImpl implements ImageProcessingDatasource {
  const ImageProcessingDatasourceImpl();

  @override
  Future<Either<Failure, LeafAnalysisModel>> processImage(
    Uint8List imageBytes,
    String imagePath,
  ) async {
    try {
      final result = await Isolate.run(() => _runOpenCvPipeline(imageBytes));

      final damagedArea =
          (result.totalArea - result.realArea).clamp(0.0, double.infinity);
      final damagePercentage =
          (damagedArea / result.totalArea * 100).clamp(0.0, 100.0);

      return Right(
        LeafAnalysisModel(
          id: const Uuid().v4(),
          imagePath: imagePath,
          originalBytes: imageBytes,
          segmentedBytes: result.segmentedBytes,
          reconstructedBytes: result.reconstructedBytes,
          realArea: result.realArea,
          totalArea: result.totalArea,
          holeArea: result.holeArea,
          damagedArea: damagedArea,
          damagePercentage: damagePercentage,
          analyzedAt: DateTime.now(),
        ),
      );
    } on _PipelineException catch (e) {
      return Left(ImageProcessingFailure(e.message));
    } catch (e) {
      return Left(ImageProcessingFailure('Erro ao processar imagem: $e'));
    }
  }
}

class _PipelineResult {
  final Uint8List segmentedBytes;
  final Uint8List reconstructedBytes;
  final double realArea;
  final double totalArea;
  final double holeArea;

  const _PipelineResult({
    required this.segmentedBytes,
    required this.reconstructedBytes,
    required this.realArea,
    required this.totalArea,
    required this.holeArea,
  });
}

class _PipelineException implements Exception {
  final String message;
  const _PipelineException(this.message);

  @override
  String toString() => message;
}

_PipelineResult _runOpenCvPipeline(Uint8List imageBytes) {
  cv.Mat? originalBgr;
  cv.Mat? resized;
  cv.Mat? hsv;
  cv.Mat? mask;
  cv.Mat? closed;
  cv.Mat? cleaned;
  cv.Mat? kernelClose;
  cv.Mat? kernelOpen;
  cv.Mat? hullMat;
  cv.Mat? segmentedMat;
  cv.Mat? reconstructedMat;
  cv.VecPoint? hullPoints;

  try {
    originalBgr = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
    if (originalBgr.isEmpty) {
      throw const _PipelineException('Nao foi possivel decodificar a imagem');
    }

    final srcW = originalBgr.cols;
    final srcH = originalBgr.rows;
    const maxWidth = 800;
    final scale = srcW > maxWidth ? maxWidth / srcW : 1.0;
    final dstW = (srcW * scale).round();
    final dstH = (srcH * scale).round();
    resized = cv.resize(originalBgr, (dstW, dstH));

    hsv = cv.cvtColor(resized, cv.COLOR_BGR2HSV);

    mask = cv.inRangebyScalar(
      hsv,
      cv.Scalar(30, 40, 40),
      cv.Scalar(90, 255, 255),
    );

    // Kernel pequeno (3x3) para CLOSE: consolida pixels da folha sem
    // preencher buracos médios — buracos com diâmetro >= 4px sobrevivem e
    // serão detectados pela passagem CCOMP de findContours mais adiante.
    kernelClose = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
    kernelOpen = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
    closed = cv.morphologyEx(mask, cv.MORPH_CLOSE, kernelClose);
    cleaned = cv.morphologyEx(closed, cv.MORPH_OPEN, kernelOpen);

    final (externalContours, externalHierarchy) =
        cv.findContours(cleaned, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
    try {
      if (externalContours.isEmpty) {
        throw const _PipelineException(
          'Nenhuma folha detectada. Verifique o fundo e a iluminacao.',
        );
      }

      int leafIdx = -1;
      double leafOuterArea = 0;
      for (int i = 0; i < externalContours.length; i++) {
        final c = externalContours[i];
        if (c.length < 3) continue;
        final a = cv.contourArea(c);
        if (a > leafOuterArea) {
          leafOuterArea = a;
          leafIdx = i;
        }
      }

      if (leafIdx < 0 || leafOuterArea <= 0) {
        throw const _PipelineException(
          'Nenhuma folha detectada. Verifique o fundo e a iluminacao.',
        );
      }

      final leafContour = externalContours[leafIdx];

      // Constrói uma máscara binária só com a folha (maior componente)
      // para que countNonZero conte exclusivamente os pixels visíveis dela.
      // Isso desconta naturalmente os buracos internos — algo que
      // cv.contourArea(leafContour) NÃO faz, pois só vê o polígono externo.
      final leafMask = cv.Mat.zeros(cleaned.rows, cleaned.cols, cv.MatType.CV_8UC1);
      try {
        final leafAsVecVecForMask = cv.VecVecPoint.fromVecPoint(leafContour);
        try {
          cv.drawContours(
            leafMask,
            leafAsVecVecForMask,
            0,
            cv.Scalar.all(255),
            thickness: -1, // preenchido
          );
        } finally {
          leafAsVecVecForMask.dispose();
        }
        // Interseção com a máscara morfologicamente limpa: assim os buracos
        // detectados (pretos em `cleaned`) ficam pretos também aqui.
        final intersected = cv.bitwiseAND(leafMask, cleaned);
        try {
          // Substitui `cleaned` por essa máscara restrita à folha selecionada,
          // descartando ruídos de outras regiões verdes da imagem.
          cleaned.dispose();
          cleaned = intersected.clone();
        } finally {
          intersected.dispose();
        }
      } finally {
        leafMask.dispose();
      }

      // realArea = pixels efetivamente brancos na máscara da folha,
      // já descontando todos os buracos internos.
      final realArea = cv.countNonZero(cleaned).toDouble();

      hullMat = cv.convexHull(leafContour);
      hullPoints = cv.VecPoint.fromMat(hullMat);
      if (hullPoints.length < 3) {
        throw const _PipelineException('Convex Hull invalido');
      }

      final totalArea = cv.contourArea(hullPoints);
      if (totalArea <= 0) {
        throw const _PipelineException('Area do Convex Hull invalida');
      }

      // Detecta buracos internos via hierarquia CCOMP (parent != -1) e
      // soma sua área. Os contornos são reaproveitados logo abaixo para
      // desenhá-los preenchidos na imagem reconstruída.
      double holeArea = 0;
      segmentedMat = cv.bitwiseAND(resized, resized, mask: cleaned);
      reconstructedMat = resized.clone();

      final (ccompContours, ccompHierarchy) =
          cv.findContours(cleaned, cv.RETR_CCOMP, cv.CHAIN_APPROX_SIMPLE);
      try {
        for (int i = 0; i < ccompContours.length; i++) {
          final parent = ccompHierarchy[i].val4;
          if (parent == -1) continue;
          final c = ccompContours[i];
          if (c.length < 3) continue;

          holeArea += cv.contourArea(c);

          // Desenha cada buraco preenchido em laranja sobre a reconstruída
          // (thickness = -1 → fill). Use uma VecVecPoint temporária.
          final holeAsVecVec = cv.VecVecPoint.fromVecPoint(c);
          try {
            cv.drawContours(
              reconstructedMat,
              holeAsVecVec,
              0,
              cv.Scalar.fromRgb(255, 140, 0),
              thickness: -1,
            );
          } finally {
            holeAsVecVec.dispose();
          }
        }
      } finally {
        ccompContours.dispose();
        ccompHierarchy.dispose();
      }

      // Contorno verde da folha real (por cima dos buracos preenchidos)
      final leafAsVecVec = cv.VecVecPoint.fromVecPoint(leafContour);
      try {
        cv.drawContours(
          reconstructedMat,
          leafAsVecVec,
          0,
          cv.Scalar.fromRgb(0, 200, 0),
          thickness: 2,
        );
      } finally {
        leafAsVecVec.dispose();
      }

      // Polígono vermelho do Convex Hull por cima de tudo
      final hullAsVecVec = cv.VecVecPoint.fromVecPoint(hullPoints);
      try {
        cv.polylines(
          reconstructedMat,
          hullAsVecVec,
          true,
          cv.Scalar.fromRgb(255, 0, 0),
          thickness: 2,
        );
      } finally {
        hullAsVecVec.dispose();
      }

      final (okSeg, segBytes) = cv.imencode('.png', segmentedMat);
      final (okRec, recBytes) = cv.imencode('.png', reconstructedMat);
      if (!okSeg || !okRec) {
        throw const _PipelineException('Falha ao codificar imagens de saida');
      }

      return _PipelineResult(
        segmentedBytes: segBytes,
        reconstructedBytes: recBytes,
        realArea: realArea,
        totalArea: totalArea,
        holeArea: holeArea,
      );
    } finally {
      externalContours.dispose();
      externalHierarchy.dispose();
    }
  } finally {
    originalBgr?.dispose();
    resized?.dispose();
    hsv?.dispose();
    mask?.dispose();
    closed?.dispose();
    cleaned?.dispose();
    kernelClose?.dispose();
    kernelOpen?.dispose();
    hullMat?.dispose();
    hullPoints?.dispose();
    segmentedMat?.dispose();
    reconstructedMat?.dispose();
  }
}
