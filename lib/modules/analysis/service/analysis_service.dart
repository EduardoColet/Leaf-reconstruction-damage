import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';
import '../repository/analysis_repository.dart';
import '../../history/repository/history_repository.dart';

// Regras de negócio da análise foliar
class AnalysisService {
  final AnalysisRepository _analysisRepository;
  final HistoryRepository _historyRepository;

  const AnalysisService(this._analysisRepository, this._historyRepository);

  /// Executa a análise e persiste o resultado no histórico
  Future<Either<Failure, LeafAnalysisModel>> analyze(
      Uint8List imageBytes, String imagePath) async {
    final result =
        await _analysisRepository.analyzeImage(imageBytes, imagePath);

    return result.fold(
      (failure) => Left(failure),
      (model) async {
        await _historyRepository.save(model);
        return Right(model);
      },
    );
  }
}
