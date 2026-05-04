import 'package:flutter_modular/flutter_modular.dart';

import '../../core/models/leaf_analysis_model.dart';
import 'view/history_detail_page.dart';
import 'view/history_page.dart';

class HistoryModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => const HistoryPage(),
      transition: TransitionType.rightToLeft,
    );
    r.child(
      '/detail',
      child: (_) => HistoryDetailPage(
        item: r.args.data as LeafAnalysisModel,
      ),
      transition: TransitionType.rightToLeft,
    );
  }
}
