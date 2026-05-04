import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../core/models/leaf_analysis_model.dart';
import '../../analysis/view/widgets/analysis_result_widget.dart';

class HistoryDetailPage extends StatelessWidget {
  final LeafAnalysisModel item;

  const HistoryDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise salva'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Modular.to.pop(),
        ),
      ),
      body: AnalysisResultWidget(result: item),
    );
  }
}
