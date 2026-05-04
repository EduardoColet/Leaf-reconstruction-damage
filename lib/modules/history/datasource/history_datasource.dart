import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/models/leaf_analysis_model.dart';

const String _historyBoxName = 'history_box';

abstract class HistoryDatasource {
  Future<Either<Failure, Unit>> save(LeafAnalysisModel model);
  Future<Either<Failure, List<LeafAnalysisModel>>> getAll();
  Future<Either<Failure, LeafAnalysisModel?>> getById(String id);
  Future<Either<Failure, Unit>> delete(String id);
  Future<Either<Failure, Unit>> clear();
}

class HistoryDatasourceImpl implements HistoryDatasource {
  Future<LazyBox> _openBox() async {
    if (Hive.isBoxOpen(_historyBoxName)) {
      return Hive.lazyBox(_historyBoxName);
    }
    return Hive.openLazyBox(_historyBoxName);
  }

  Map<String, dynamic> _toMap(LeafAnalysisModel m) => {
        'id': m.id,
        'imagePath': m.imagePath,
        'originalBytes': m.originalBytes.toList(growable: false),
        'segmentedBytes': m.segmentedBytes.toList(growable: false),
        'reconstructedBytes': m.reconstructedBytes.toList(growable: false),
        'realArea': m.realArea,
        'totalArea': m.totalArea,
        'holeArea': m.holeArea,
        'damagedArea': m.damagedArea,
        'damagePercentage': m.damagePercentage,
        'analyzedAt': m.analyzedAt.toIso8601String(),
      };

  Uint8List _toBytes(dynamic value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    if (value is List) return Uint8List.fromList(value.cast<int>());
    throw ArgumentError('Valor inválido para bytes: ${value.runtimeType}');
  }

  LeafAnalysisModel? _fromMap(Map raw) {
    try {
      return LeafAnalysisModel(
        id: raw['id'] as String,
        imagePath: raw['imagePath'] as String,
        originalBytes: _toBytes(raw['originalBytes']),
        segmentedBytes: _toBytes(raw['segmentedBytes']),
        reconstructedBytes: _toBytes(raw['reconstructedBytes']),
        realArea: (raw['realArea'] as num).toDouble(),
        totalArea: (raw['totalArea'] as num).toDouble(),
        holeArea: (raw['holeArea'] as num).toDouble(),
        damagedArea: (raw['damagedArea'] as num).toDouble(),
        damagePercentage: (raw['damagePercentage'] as num).toDouble(),
        analyzedAt: DateTime.parse(raw['analyzedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Either<Failure, Unit>> save(LeafAnalysisModel model) async {
    try {
      final box = await _openBox();
      await box.put(model.id, _toMap(model));
      await box.flush();
      return const Right(unit);
    } catch (e) {
      return Left(StorageFailure('Falha ao salvar análise: $e'));
    }
  }

  @override
  Future<Either<Failure, List<LeafAnalysisModel>>> getAll() async {
    try {
      final box = await _openBox();
      final items = <LeafAnalysisModel>[];
      for (final key in box.keys) {
        final raw = await box.get(key);
        if (raw is Map) {
          final model = _fromMap(Map.from(raw));
          if (model != null) items.add(model);
        }
      }
      items.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
      return Right(items);
    } catch (e) {
      return Left(StorageFailure('Falha ao carregar histórico: $e'));
    }
  }

  @override
  Future<Either<Failure, LeafAnalysisModel?>> getById(String id) async {
    try {
      final box = await _openBox();
      final raw = await box.get(id);
      if (raw is Map) {
        return Right(_fromMap(Map.from(raw)));
      }
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure('Falha ao carregar análise: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(String id) async {
    try {
      final box = await _openBox();
      await box.delete(id);
      await box.flush();
      return const Right(unit);
    } catch (e) {
      return Left(StorageFailure('Falha ao remover análise: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> clear() async {
    try {
      final box = await _openBox();
      await box.clear();
      await box.flush();
      return const Right(unit);
    } catch (e) {
      return Left(StorageFailure('Falha ao limpar histórico: $e'));
    }
  }
}
