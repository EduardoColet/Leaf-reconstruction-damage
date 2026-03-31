import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../core/models/capture_args.dart';
import '../controller/test_gallery_cubit.dart';
import '../../../core/di/injection_container.dart';

class TestGalleryPage extends StatelessWidget {
  const TestGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<TestGalleryCubit>()..loadImages(),
      child: const _TestGalleryView(),
    );
  }
}

class _TestGalleryView extends StatelessWidget {
  const _TestGalleryView();

  // Extrai apenas o nome do arquivo do caminho do asset
  String _fileName(String assetPath) {
    return assetPath.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Imagens de Teste'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<TestGalleryCubit, TestGalleryState>(
        listener: (context, state) {
          // Quando a imagem estiver carregada, navega para análise
          if (state is TestGalleryImageReady) {
            Modular.to.pushNamed(
              '/analysis',
              arguments: CaptureArgs(
                imageBytes: state.imageBytes,
                imagePath: state.assetPath,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TestGalleryLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            );
          }

          if (state is TestGalleryLoadingImage) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 12),
                  Text('Carregando imagem...'),
                ],
              ),
            );
          }

          if (state is TestGalleryFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          if (state is TestGalleryLoaded) {
            if (state.imagePaths.isEmpty) {
              return const _EmptyGalleryWidget();
            }

            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: state.imagePaths.length,
              itemBuilder: (context, index) {
                final assetPath = state.imagePaths[index];
                return _ImageCard(
                  assetPath: assetPath,
                  fileName: _fileName(assetPath),
                  onTap: () =>
                      BlocProvider.of<TestGalleryCubit>(context).selectImage(assetPath),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Card individual de imagem na grade
// ──────────────────────────────────────────────────────
class _ImageCard extends StatelessWidget {
  final String assetPath;
  final String fileName;
  final VoidCallback onTap;

  const _ImageCard({
    required this.assetPath,
    required this.fileName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: Colors.grey[100],
                  child: const Icon(Icons.broken_image,
                      size: 48, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.eco, size: 14, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Estado vazio — pasta sem imagens
// ──────────────────────────────────────────────────────
class _EmptyGalleryWidget extends StatelessWidget {
  const _EmptyGalleryWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma imagem encontrada',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adicione imagens .jpg ou .png na pasta:\nassets/test_images/',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () =>
                  BlocProvider.of<TestGalleryCubit>(context).loadImages(),
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
                side: const BorderSide(color: Color(0xFF4CAF50)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
