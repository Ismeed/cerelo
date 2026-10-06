import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/personnel_config.dart';
import 'core/router/personnel_router.dart';

/// Root widget for the Cerelo Personnel App.
class CereloPersonnelApp extends ConsumerWidget {
  const CereloPersonnelApp({super.key, required this.config});

  final PersonnelConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(personnelRouterProvider);

    return MaterialApp.router(
      title: 'Cerelo — Personnel',
      debugShowCheckedModeBanner: false,
      theme: CereloTheme.light,
      routerConfig: router,
    );
  }
}
