import 'package:flutter_modular/flutter_modular.dart';

import 'view/history_page.dart';

class HistoryModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => const HistoryPage(),
      transition: TransitionType.rightToLeft,
    );
  }
}
