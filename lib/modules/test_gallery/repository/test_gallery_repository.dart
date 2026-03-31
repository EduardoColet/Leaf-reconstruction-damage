import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../core/errors/app_exceptions.dart';
import '../datasource/asset_images_datasource.dart';

abstract class TestGalleryRepository {
  Future<Either<Failure, List<String>>> listImages();
  Future<Either<Failure, Uint8List>> loadImage(String assetPath);
}

class TestGalleryRepositoryImpl implements TestGalleryRepository {
  final AssetImagesDatasource _datasource;

  const TestGalleryRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<String>>> listImages() async {
    try {
      final paths = await _datasource.listTestImages();
      return Right(paths);
    } catch (e) {
      return Left(UnexpectedFailure('Erro ao listar imagens de teste: $e'));
    }
  }

  @override
  Future<Either<Failure, Uint8List>> loadImage(String assetPath) async {
    try {
      final bytes = await _datasource.loadAssetBytes(assetPath);
      return Right(bytes);
    } catch (e) {
      return Left(UnexpectedFailure('Erro ao carregar imagem: $e'));
    }
  }
}
