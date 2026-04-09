import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';

abstract class ImageProcessingDatasource {
  Future<Either<Failure, LeafAnalysisModel>> processImage(
    Uint8List imageBytes,
    String imagePath,
  );
}
