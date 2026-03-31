import 'dart:typed_data';
// ignore_for_file: unnecessary_import

import 'package:dartz/dartz.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';
import '../datasource/image_processing_datasource.dart';

abstract class AnalysisRepository {
  Future<Either<Failure, LeafAnalysisModel>> analyzeImage(
      Uint8List imageBytes, String imagePath);
}

class AnalysisRepositoryImpl implements AnalysisRepository {
  final ImageProcessingDatasource _datasource;

  const AnalysisRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, LeafAnalysisModel>> analyzeImage(
      Uint8List imageBytes, String imagePath) async {
    try {
      return await _datasource.processImage(imageBytes, imagePath);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
