import 'package:flutter/material.dart';

import '../theme.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: RadiantColors.textMuted),
        ),
      ),
    );
  }
}

/// Temporary Settings tab with the one action that already works.
class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({
    super.key,
    required this.actionLabel,
    required this.onAction,
  });

  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Display and alert settings arrive in step 6.',
            style: TextStyle(color: RadiantColors.textMuted),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () => onAction(),
            style: OutlinedButton.styleFrom(
              foregroundColor: RadiantColors.red,
              side: const BorderSide(color: RadiantColors.red),
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
