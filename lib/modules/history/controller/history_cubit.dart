import 'package:flutter_bloc/flutter_bloc.dart';

import '../repository/history_repository.dart';
import 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  final HistoryRepository _repository;

  HistoryCubit(this._repository) : super(const HistoryInitial());

  Future<void> load() async {
    emit(const HistoryLoading());
    final result = await _repository.getAll();
    result.fold(
      (failure) => emit(HistoryFailure(failure.message)),
      (items) => emit(HistoryLoaded(items)),
    );
  }

  Future<void> delete(String id) async {
    final result = await _repository.delete(id);
    await result.fold(
      (failure) async => emit(HistoryFailure(failure.message)),
      (_) async => load(),
    );
  }

  Future<void> clearAll() async {
    final result = await _repository.clear();
    await result.fold(
      (failure) async => emit(HistoryFailure(failure.message)),
      (_) async => load(),
    );
  }
}
