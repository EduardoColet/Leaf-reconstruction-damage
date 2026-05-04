import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/app_module.dart';
import 'core/di/injection_container.dart';

const String kHistoryBoxName = 'history_box';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Hive para armazenamento local
  await Hive.initFlutter();

  // Pré-abre a box do histórico para diagnóstico e garantia de
  // que o arquivo será criado antes da primeira gravação
  final box = await Hive.openLazyBox(kHistoryBoxName);

  if (kDebugMode) {
    final docs = await getApplicationDocumentsDirectory();
    debugPrint('[LeafScope] Documents dir: ${docs.path}');
    debugPrint(
      '[LeafScope] Hive box "$kHistoryBoxName" aberta — '
      '${box.length} item(ns) carregado(s)',
    );
  }

  // Configura injeção de dependências
  await setupInjection();

  runApp(
    ModularApp(
      module: AppModule(),
      child: const AppWidget(),
    ),
  );
}
