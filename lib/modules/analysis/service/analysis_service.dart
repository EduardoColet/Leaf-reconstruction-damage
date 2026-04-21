import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';
import '../repository/analysis_repository.dart';

// Regras de negócio da análise foliar
class AnalysisService {
  final AnalysisRepository _analysisRepository;

  const AnalysisService(this._analysisRepository);

  /// Executa a análise da imagem
  Future<Either<Failure, LeafAnalysisModel>> analyze(
      Uint8List imageBytes, String imagePath) async {
    return _analysisRepository.analyzeImage(imageBytes, imagePath);
  }
}
