import 'package:flutter_modular/flutter_modular.dart';

import '../../core/models/capture_args.dart';
import 'view/analysis_page.dart';

class AnalysisModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => AnalysisPage(
        args: r.args.data as CaptureArgs,
      ),
      transition: TransitionType.rightToLeft,
    );
  }
}
