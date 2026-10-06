import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';

/// Root widget for the Cerelo Customer App.
class CereloCustomerApp extends ConsumerWidget {
  const CereloCustomerApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Cerelo',
      debugShowCheckedModeBanner: false,
      theme: CereloTheme.light,
      routerConfig: router,
    );
  }
}
