import 'package:dartz/dartz.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';

// Interface do datasource de armazenamento local
abstract class LocalStorageDatasource {
  Future<Either<Failure, List<LeafAnalysisModel>>> getAll();
  Future<Either<Failure, Unit>> save(LeafAnalysisModel model);
  Future<Either<Failure, Unit>> delete(String id);
}

// Implementação com Hive — será completada no módulo de histórico
class LocalStorageDatasourceImpl implements LocalStorageDatasource {
  @override
  Future<Either<Failure, List<LeafAnalysisModel>>> getAll() async {
    // TODO: implementar leitura do Hive
    return const Right([]);
  }

  @override
  Future<Either<Failure, Unit>> save(LeafAnalysisModel model) async {
    // TODO: implementar escrita no Hive
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> delete(String id) async {
    // TODO: implementar remoção no Hive
    return const Right(unit);
  }
}
