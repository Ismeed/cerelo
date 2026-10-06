import 'package:cerelo_ui/cerelo_ui.dart';
import 'package:flutter/material.dart';

/// Final-mile delivery screen — doorstep handoff to Receiver.
///
/// Full delivery confirmation + payment collection + QR verification
/// implementation deferred to feature prompts.
class DeliveryScreen extends StatelessWidget {
  const DeliveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deliveries')),
      body: const CereloEmptyState(
        icon: Icons.delivery_dining_outlined,
        title: 'No active deliveries',
        description: 'Your delivery route will appear here.',
      ),
    );
  }
}
