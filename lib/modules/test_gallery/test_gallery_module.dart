import 'package:flutter_modular/flutter_modular.dart';

import 'view/test_gallery_page.dart';

class TestGalleryModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => const TestGalleryPage(),
      transition: TransitionType.rightToLeft,
    );
  }
}
