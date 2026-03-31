import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/leaf_analysis_model.dart';
import '../service/analysis_service.dart';

part 'analysis_event.dart';
part 'analysis_state.dart';

class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {
  final AnalysisService _service;

  AnalysisBloc(this._service) : super(AnalysisInitial()) {
    on<AnalyzeImageEvent>(_onAnalyzeImage);
    on<ResetAnalysisEvent>(_onReset);
  }

  Future<void> _onAnalyzeImage(
    AnalyzeImageEvent event,
    Emitter<AnalysisState> emit,
  ) async {
    emit(AnalysisLoading());

    final result = await _service.analyze(event.imageBytes, event.imagePath);

    result.fold(
      (failure) => emit(AnalysisFailure(failure.message)),
      (model) => emit(AnalysisSuccess(model)),
    );
  }

  void _onReset(ResetAnalysisEvent event, Emitter<AnalysisState> emit) {
    emit(AnalysisInitial());
  }
}
