part of 'analysis_bloc.dart';

abstract class AnalysisState {}

class AnalysisInitial extends AnalysisState {}

class AnalysisLoading extends AnalysisState {}

class AnalysisSuccess extends AnalysisState {
  final LeafAnalysisModel result;
  AnalysisSuccess(this.result);
}

class AnalysisFailure extends AnalysisState {
  final String message;
  AnalysisFailure(this.message);
}
