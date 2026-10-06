import 'package:flutter/material.dart';
import '../theme/cerelo_colors.dart';

/// Full-screen loading overlay for async operations.
class CereloLoading extends StatelessWidget {
  const CereloLoading({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: CereloColors.orange,
            strokeWidth: 3,
          ),
          if (message != null) ...
            [
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(
                  color: CereloColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
        ],
      ),
    );
  }
}
