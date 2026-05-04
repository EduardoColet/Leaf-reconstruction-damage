import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';
import '../../history/repository/history_repository.dart';
import '../repository/analysis_repository.dart';

// Regras de negócio da análise foliar
class AnalysisService {
  final AnalysisRepository _analysisRepository;
  final HistoryRepository _historyRepository;

  const AnalysisService(this._analysisRepository, this._historyRepository);

  /// Executa a análise da imagem e persiste no histórico em caso de sucesso.
  Future<Either<Failure, LeafAnalysisModel>> analyze(
      Uint8List imageBytes, String imagePath) async {
    final result = await _analysisRepository.analyzeImage(imageBytes, imagePath);
    return result.fold(
      (failure) async => Left(failure),
      (model) async {
        // Falhas no salvamento não impedem a entrega do resultado ao usuário
        await _historyRepository.save(model);
        return Right(model);
      },
    );
  }
}
