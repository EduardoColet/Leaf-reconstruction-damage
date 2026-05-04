import 'package:dartz/dartz.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';
import '../datasource/history_datasource.dart';

abstract class HistoryRepository {
  Future<Either<Failure, Unit>> save(LeafAnalysisModel model);
  Future<Either<Failure, List<LeafAnalysisModel>>> getAll();
  Future<Either<Failure, LeafAnalysisModel?>> getById(String id);
  Future<Either<Failure, Unit>> delete(String id);
  Future<Either<Failure, Unit>> clear();
}

class HistoryRepositoryImpl implements HistoryRepository {
  final HistoryDatasource _datasource;
  const HistoryRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, Unit>> save(LeafAnalysisModel model) =>
      _datasource.save(model);

  @override
  Future<Either<Failure, List<LeafAnalysisModel>>> getAll() =>
      _datasource.getAll();

  @override
  Future<Either<Failure, LeafAnalysisModel?>> getById(String id) =>
      _datasource.getById(id);

  @override
  Future<Either<Failure, Unit>> delete(String id) => _datasource.delete(id);

  @override
  Future<Either<Failure, Unit>> clear() => _datasource.clear();
}
