import 'package:flutter_modular/flutter_modular.dart';

import '../modules/home/home_module.dart';
import '../modules/capture/capture_module.dart';
import '../modules/analysis/analysis_module.dart';
import '../modules/test_gallery/test_gallery_module.dart';

class AppModule extends Module {
  @override
  void routes(RouteManager r) {
    r.module('/', module: HomeModule());
    r.module('/capture', module: CaptureModule());
    r.module('/analysis', module: AnalysisModule());
    r.module('/test-gallery', module: TestGalleryModule());
  }
}
