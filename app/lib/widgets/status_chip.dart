import 'package:flutter/material.dart';

import '../theme.dart';

String two(int n) => n.toString().padLeft(2, '0');

String clockLabel(DateTime t) =>
    '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String thousands(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

String intersectionName(int id) => 'Intersection ${two(id)}';

class ChipStyle {
  const ChipStyle(this.label, this.background, this.foreground, [this.icon]);

  final String label;
  final Color background;
  final Color foreground;

  /// Shown before the label (color-blind-safe signals).
  final IconData? icon;
}

/// Short mode chip (summary cards).
ChipStyle modeChip(String mode) {
  switch (mode) {
    case 'emergency':
      return const ChipStyle('EMERGENCY', RadiantColors.amber, Colors.black);
    case 'idle':
      return const ChipStyle('IDLE', RadiantColors.yellow, Colors.black);
    default:
      return const ChipStyle('NORMAL', RadiantColors.green, Colors.black);
  }
}

/// Long mode chip (intersection picker).
ChipStyle modeLongChip(String mode) {
  switch (mode) {
    case 'emergency':
      return const ChipStyle(
          'EMERGENCY DETECTED', RadiantColors.amber, Colors.black);
    case 'idle':
      return const ChipStyle('IDLE', RadiantColors.yellow, Colors.black);
    default:
      return const ChipStyle('NORMAL', RadiantColors.green, Colors.black);
  }
}

/// Chip on the camera feed card.
ChipStyle cameraChip(String mode, {required bool offline}) {
  if (offline) {
    return const ChipStyle('LAST SAVED', RadiantColors.disabled, Colors.white);
  }
  switch (mode) {
    case 'emergency':
      return const ChipStyle(
          'EMERGENCY DETECTED', RadiantColors.amber, Colors.black);
    case 'idle':
      return const ChipStyle(
          'IDLE · FLASHING YELLOW', RadiantColors.yellow, Colors.black);
    default:
      return const ChipStyle('LIVE · NORMAL', RadiantColors.green, Colors.black);
  }
}

/// Signal chip on a lane card. With [safe] set, each state also gets its own
/// icon so it can be told apart without relying on color.
ChipStyle signalChip(String signal, int? seconds, {bool safe = false}) {
  switch (signal) {
    case 'go':
      return ChipStyle(
        seconds == null ? 'GO' : 'GO ${seconds}s',
        RadiantColors.green,
        Colors.black,
        safe ? Icons.check : null,
      );
    case 'yellow':
      return ChipStyle(
        seconds == null ? 'YELLOW' : 'YELLOW ${seconds}s',
        RadiantColors.amber,
        Colors.black,
        safe ? Icons.change_history : null,
      );
    case 'flashYellow':
      return ChipStyle(
        'FLASH YELLOW',
        RadiantColors.yellow,
        Colors.black,
        safe ? Icons.warning_amber : null,
      );
    default:
      return ChipStyle(
        'STOP',
        RadiantColors.red,
        Colors.white,
        safe ? Icons.stop : null,
      );
  }
}

/// Type chip on an event log entry.
ChipStyle eventChip(String type) {
  switch (type) {
    case 'emergencyDetected':
      return const ChipStyle(
          'EMERGENCY DETECTED', RadiantColors.amber, Colors.black);
    case 'idleMode':
      return const ChipStyle('IDLE MODE', RadiantColors.yellow, Colors.black);
    case 'pedestrianCrossing':
      return const ChipStyle(
          'PEDESTRIAN CROSSING', RadiantColors.green, Colors.black);
    default:
      return const ChipStyle('DENSITY ADJUST', RadiantColors.disabled, Colors.white);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.style, {super.key, this.compact = false});

  final ChipStyle style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (style.icon != null) ...[
            Icon(style.icon, size: compact ? 10 : 12, color: style.foreground),
            const SizedBox(width: 3),
          ],
          Text(
            style.label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
              color: style.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
