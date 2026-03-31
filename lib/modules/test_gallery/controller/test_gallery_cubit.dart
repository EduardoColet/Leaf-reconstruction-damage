import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../repository/test_gallery_repository.dart';

part 'test_gallery_state.dart';

class TestGalleryCubit extends Cubit<TestGalleryState> {
  final TestGalleryRepository _repository;

  TestGalleryCubit(this._repository) : super(TestGalleryInitial());

  Future<void> loadImages() async {
    emit(TestGalleryLoading());

    final result = await _repository.listImages();
    result.fold(
      (failure) => emit(TestGalleryFailure(failure.message)),
      (paths) => emit(TestGalleryLoaded(paths)),
    );
  }

  Future<void> selectImage(String assetPath) async {
    emit(TestGalleryLoadingImage());

    final result = await _repository.loadImage(assetPath);
    result.fold(
      (failure) => emit(TestGalleryFailure(failure.message)),
      (bytes) => emit(TestGalleryImageReady(
        assetPath: assetPath,
        imageBytes: bytes,
      )),
    );
  }
}
