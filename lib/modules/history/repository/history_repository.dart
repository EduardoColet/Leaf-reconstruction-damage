import 'package:dartz/dartz.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';
import '../datasource/local_storage_datasource.dart';

// Interface do repositório de histórico
abstract class HistoryRepository {
  Future<Either<Failure, List<LeafAnalysisModel>>> getAll();
  Future<Either<Failure, Unit>> save(LeafAnalysisModel model);
  Future<Either<Failure, Unit>> delete(String id);
}

// Implementação concreta
class HistoryRepositoryImpl implements HistoryRepository {
  final LocalStorageDatasource _datasource;

  const HistoryRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<LeafAnalysisModel>>> getAll() async {
    try {
      return await _datasource.getAll();
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> save(LeafAnalysisModel model) async {
    try {
      return await _datasource.save(model);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(String id) async {
    try {
      return await _datasource.delete(id);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
