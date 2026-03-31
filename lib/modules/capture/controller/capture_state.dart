part of 'capture_cubit.dart';

abstract class CaptureState {}

class CaptureInitial extends CaptureState {}

class CaptureImageSelected extends CaptureState {
  final String imagePath;
  final Uint8List imageBytes;

  CaptureImageSelected({required this.imagePath, required this.imageBytes});
}
