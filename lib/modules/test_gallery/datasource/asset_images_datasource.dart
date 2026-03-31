import 'package:flutter/services.dart';

// Interface
abstract class AssetImagesDatasource {
  /// Retorna a lista de caminhos de asset disponíveis em assets/test_images/
  Future<List<String>> listTestImages();

  /// Carrega os bytes de um asset pelo caminho
  Future<Uint8List> loadAssetBytes(String assetPath);
}

// Implementação
class AssetImagesDatasourceImpl implements AssetImagesDatasource {
  static const _folder = 'assets/test_images';

  @override
  Future<List<String>> listTestImages() async {
    // Flutter 3.10+ usa AssetManifest.loadFromAssetBundle()
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    return manifest
        .listAssets()
        .where((key) =>
            key.startsWith(_folder) &&
            (key.endsWith('.png') ||
                key.endsWith('.jpg') ||
                key.endsWith('.jpeg')))
        .toList()
      ..sort();
  }

  @override
  Future<Uint8List> loadAssetBytes(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }
}
