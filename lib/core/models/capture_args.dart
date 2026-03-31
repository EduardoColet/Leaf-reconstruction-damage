import 'dart:typed_data';

/// Dados passados da tela de captura para a análise.
class CaptureArgs {
  final Uint8List imageBytes;
  final String imagePath; // caminho original (válido em mobile; blob URL no web)

  const CaptureArgs({required this.imageBytes, required this.imagePath});
}
