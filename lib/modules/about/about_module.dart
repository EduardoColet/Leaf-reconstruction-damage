import 'package:flutter_modular/flutter_modular.dart';

import 'view/about_page.dart';

class AboutModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => const AboutPage(),
      transition: TransitionType.rightToLeft,
    );
  }
}
