import 'package:get_it/get_it.dart';

import '../../modules/analysis/controller/analysis_bloc.dart';
import '../../modules/analysis/datasource/image_processing_datasource.dart';
import '../../modules/analysis/repository/analysis_repository.dart';
import '../../modules/analysis/service/analysis_service.dart';

import '../../modules/test_gallery/controller/test_gallery_cubit.dart';
import '../../modules/test_gallery/datasource/asset_images_datasource.dart';
import '../../modules/test_gallery/repository/test_gallery_repository.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupInjection() async {
  // DataSources
  getIt.registerLazySingleton<ImageProcessingDatasource>(
    () => ImageProcessingDatasourceImpl(),
  );

  // Repositories
  getIt.registerLazySingleton<AnalysisRepository>(
    () => AnalysisRepositoryImpl(getIt()),
  );

  // Services
  getIt.registerLazySingleton<AnalysisService>(
    () => AnalysisService(getIt()),
  );

  // BLoCs / Cubits — factory para criar nova instância a cada uso
  getIt.registerFactory<AnalysisBloc>(
    () => AnalysisBloc(getIt()),
  );
  // TestGallery
  getIt.registerLazySingleton<AssetImagesDatasource>(
    () => AssetImagesDatasourceImpl(),
  );
  getIt.registerLazySingleton<TestGalleryRepository>(
    () => TestGalleryRepositoryImpl(getIt()),
  );
  getIt.registerFactory<TestGalleryCubit>(
    () => TestGalleryCubit(getIt()),
  );
}
