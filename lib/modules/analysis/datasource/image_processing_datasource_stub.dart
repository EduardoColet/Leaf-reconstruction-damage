import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';
import 'image_processing_datasource_base.dart';

class ImageProcessingDatasourceImpl implements ImageProcessingDatasource {
  const ImageProcessingDatasourceImpl();

  @override
  Future<Either<Failure, LeafAnalysisModel>> processImage(
    Uint8List imageBytes,
    String imagePath,
  ) async {
    return Left(
      ImageProcessingFailure(
        'O processamento com OpenCV nativo nao esta disponivel no Flutter Web. '
        'Use Android, Windows ou Linux para executar esta versao.',
      ),
    );
  }
}
