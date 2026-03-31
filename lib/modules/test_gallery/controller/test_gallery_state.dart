part of 'test_gallery_cubit.dart';

abstract class TestGalleryState {}

class TestGalleryInitial extends TestGalleryState {}

class TestGalleryLoading extends TestGalleryState {}

class TestGalleryLoadingImage extends TestGalleryState {}

class TestGalleryLoaded extends TestGalleryState {
  final List<String> imagePaths;
  TestGalleryLoaded(this.imagePaths);
}

class TestGalleryImageReady extends TestGalleryState {
  final String assetPath;
  final Uint8List imageBytes;
  TestGalleryImageReady({required this.assetPath, required this.imageBytes});
}

class TestGalleryFailure extends TestGalleryState {
  final String message;
  TestGalleryFailure(this.message);
}
