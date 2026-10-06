import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const CereloEmptyState(
        icon: Icons.grid_view_rounded,
        title: 'Operations Dashboard',
        description: 'Your active tasks will appear here.',
      ),
    );
  }
}
