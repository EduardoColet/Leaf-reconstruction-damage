import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../controller/analysis_bloc.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/models/capture_args.dart';
import 'widgets/analysis_loading_widget.dart';
import 'widgets/analysis_error_widget.dart';
import 'widgets/analysis_result_widget.dart';

class AnalysisPage extends StatelessWidget {
  final CaptureArgs args;

  const AnalysisPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AnalysisBloc>()
        ..add(
          AnalyzeImageEvent(
            imageBytes: args.imageBytes,
            imagePath: args.imagePath,
          ),
        ),
      child: const _AnalysisView(),
    );
  }
}

class _AnalysisView extends StatelessWidget {
  const _AnalysisView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado da Análise'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Modular.to.pop(),
        ),
      ),
      body: BlocBuilder<AnalysisBloc, AnalysisState>(
        builder: (context, state) {
          if (state is AnalysisLoading) {
            return const AnalysisLoadingWidget();
          }
          if (state is AnalysisFailure) {
            return AnalysisErrorWidget(message: state.message);
          }
          if (state is AnalysisSuccess) {
            return AnalysisResultWidget(result: state.result);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
