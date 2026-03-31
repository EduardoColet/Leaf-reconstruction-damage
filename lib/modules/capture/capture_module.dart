import 'package:flutter_modular/flutter_modular.dart';

import 'view/capture_page.dart';

class CaptureModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => const CapturePage(),
      transition: TransitionType.rightToLeft,
    );
  }
}
