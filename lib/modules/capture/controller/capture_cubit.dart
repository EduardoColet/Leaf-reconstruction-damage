import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

part 'capture_state.dart';

class CaptureCubit extends Cubit<CaptureState> {
  CaptureCubit() : super(CaptureInitial());

  void imageSelected(String path, Uint8List bytes) {
    emit(CaptureImageSelected(imagePath: path, imageBytes: bytes));
  }

  void reset() {
    emit(CaptureInitial());
  }
}
