import 'package:equatable/equatable.dart';

import '../../../core/models/leaf_analysis_model.dart';

abstract class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => [];
}

class HistoryInitial extends HistoryState {
  const HistoryInitial();
}

class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

class HistoryLoaded extends HistoryState {
  final List<LeafAnalysisModel> items;
  const HistoryLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class HistoryFailure extends HistoryState {
  final String message;
  const HistoryFailure(this.message);

  @override
  List<Object?> get props => [message];
}
