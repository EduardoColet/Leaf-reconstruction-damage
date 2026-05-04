import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:hive/hive.dart';

import '../main.dart' show kHistoryBoxName;

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Em pausa, inativo ou destacado, garante que tudo foi gravado em disco
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _flushHive();
    }
  }

  Future<void> _flushHive() async {
    try {
      if (Hive.isBoxOpen(kHistoryBoxName)) {
        await Hive.lazyBox(kHistoryBoxName).flush();
        if (kDebugMode) {
          debugPrint('[LeafScope] Hive flush executado');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LeafScope] Erro ao executar flush: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LeafScope',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF4CAF50),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      routerConfig: Modular.routerConfig,
    );
  }
}
