import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/leaf_analysis_model.dart';
import '../repository/history_repository.dart';

part 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  final HistoryRepository _repository;

  HistoryCubit(this._repository) : super(HistoryInitial());

  Future<void> loadHistory() async {
    emit(HistoryLoading());

    final result = await _repository.getAll();

    result.fold(
      (failure) => emit(HistoryFailure(failure.message)),
      (items) => emit(HistoryLoaded(items)),
    );
  }
}
