// Classe base de falhas do aplicativo
abstract class Failure {
  final String message;
  const Failure(this.message);
}

// Falha durante o processamento da imagem
class ImageProcessingFailure extends Failure {
  const ImageProcessingFailure(super.message);
}

// Falha no armazenamento local
class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

// Falha ao acessar câmera ou galeria
class CameraFailure extends Failure {
  const CameraFailure(super.message);
}

// Falha genérica inesperada
class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
