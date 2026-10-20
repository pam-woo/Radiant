import 'package:flutter/material.dart';

import '../../state/settings_state.dart';
import '../../theme.dart';

/// Settings tab shared by the admin and driver apps (the driver version adds
/// sound and vibration).
class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.driver,
    required this.actionLabel,
    required this.onAction,
  });

  final bool driver;

  /// "Sign out" for admins, "Switch user type" for drivers.
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RadiantColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RadiantColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver ? 'Alerts & display' : 'Display & notifications',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _SwitchRow(
                title: driver
                    ? 'Emergency vehicle alerts'
                    : 'Emergency detection alerts',
                subtitle: driver
                    ? 'Notify me when one is approaching.'
                    : 'Notify me when an emergency vehicle is detected.',
                value: s.alertsEnabled,
                onChanged: s.setAlertsEnabled,
              ),
              if (driver) ...[
                _SwitchRow(
                  title: 'Alert sound',
                  subtitle: 'Play a tone with each alert.',
                  value: s.soundEnabled,
                  onChanged: s.setSoundEnabled,
                ),
                _SwitchRow(
                  title: 'Vibration',
                  subtitle: 'Vibrate with each alert.',
                  value: s.vibrationEnabled,
                  onChanged: s.setVibrationEnabled,
                ),
              ],
              _SwitchRow(
                title: 'High-contrast mode',
                subtitle: 'Bold colors on black.',
                value: s.highContrast,
                onChanged: s.setHighContrast,
              ),
              _TextSizeRow(
                selected: s.textSize,
                onChanged: s.setTextSize,
              ),
              _SwitchRow(
                title: 'Color-blind-safe signals',
                subtitle: 'Adds icons and labels to signal states.',
                value: s.colorBlindSafe,
                onChanged: s.setColorBlindSafe,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: RadiantColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: (v) => onChanged(v),
                thumbColor: const WidgetStatePropertyAll(Colors.white),
                trackColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? RadiantColors.green
                      : RadiantColors.disabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextSizeRow extends StatelessWidget {
  const _TextSizeRow({required this.selected, required this.onChanged});

  final TextSize selected;
  final Future<void> Function(TextSize) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Text size',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Make text larger.',
                  style: TextStyle(
                    fontSize: 11,
                    color: RadiantColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _SizeButton(
            label: 'A-',
            description: 'Smaller text',
            selected: selected == TextSize.small,
            onTap: () => onChanged(TextSize.small),
          ),
          _SizeButton(
            label: 'A',
            description: 'Normal text',
            selected: selected == TextSize.normal,
            onTap: () => onChanged(TextSize.normal),
          ),
          _SizeButton(
            label: 'A+',
            description: 'Larger text',
            selected: selected == TextSize.large,
            onTap: () => onChanged(TextSize.large),
          ),
        ],
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Semantics(
        button: true,
        selected: selected,
        label: description,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: selected ? RadiantColors.maroon : RadiantColors.background,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected
                  ? RadiantColors.maroonBright
                  : RadiantColors.surfaceBorder,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 36,
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
