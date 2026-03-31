part of 'analysis_bloc.dart';

abstract class AnalysisEvent {}

class AnalyzeImageEvent extends AnalysisEvent {
  final Uint8List imageBytes;
  final String imagePath;

  AnalyzeImageEvent({required this.imageBytes, required this.imagePath});
}

class ResetAnalysisEvent extends AnalysisEvent {}
