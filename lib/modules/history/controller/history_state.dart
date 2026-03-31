part of 'history_cubit.dart';

abstract class HistoryState {}

class HistoryInitial extends HistoryState {}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final List<LeafAnalysisModel> items;
  HistoryLoaded(this.items);
}

class HistoryFailure extends HistoryState {
  final String message;
  HistoryFailure(this.message);
}
