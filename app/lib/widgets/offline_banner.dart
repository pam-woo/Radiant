import 'package:flutter/material.dart';

import '../theme.dart';

/// Shown when the app is displaying the last saved data.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RadiantColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: RadiantColors.surfaceBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, size: 16, color: RadiantColors.textMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'No connection. Showing the last saved data.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
