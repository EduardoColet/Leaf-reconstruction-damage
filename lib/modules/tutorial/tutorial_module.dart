import 'package:flutter_modular/flutter_modular.dart';

import 'view/tutorial_page.dart';

class TutorialModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => const TutorialPage(),
      transition: TransitionType.rightToLeft,
    );
  }
}
