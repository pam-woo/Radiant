import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/radiant_repository.dart';
import '../../state/settings_state.dart';
import '../../theme.dart';
import '../../widgets/status_chip.dart';
import 'emergency_mini_map.dart';

/// Full-screen driver alert for an approaching emergency vehicle. It keeps
/// updating while open and tells the driver when the vehicle has passed.
class EmergencyAlertScreen extends StatelessWidget {
  const EmergencyAlertScreen({
    super.key,
    required this.repo,
    required this.initial,
  });

  final RadiantRepository repo;

  /// The alert that opened this screen, kept so the screen still makes sense
  /// after the vehicle is gone.
  final ActiveEmergency initial;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final live = repo.emergencyFor(initial.intersectionId);
        final active = live != null;
        final alert = live ?? initial;
        final settings = SettingsScope.of(context);

        return Scaffold(
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: RadiantColors.red,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active
                              ? 'EMERGENCY VEHICLE APPROACHING'
                              : 'EMERGENCY VEHICLE PASSED',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          active
                              ? alert.headline
                              : 'The ${alert.vehicleLabel.toLowerCase()} has passed',
                          style: const TextStyle(
                            fontSize: 28,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${alert.intersectionName} | '
                          '${active ? alert.distanceLabel : 'no longer approaching'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EmergencyMiniMap(
                        lane: alert.lane,
                        vehicleLabel: alert.vehicleLabel,
                        visible: active,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: RadiantColors.amber,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'What to do',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: RadiantColors.amber,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              active
                                  ? alert.instruction
                                  : 'You can carry on driving normally.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          StatusChip(
                            ChipStyle(
                              settings.soundEnabled ? 'Sound on' : 'Sound off',
                              RadiantColors.disabled,
                              Colors.white,
                            ),
                          ),
                          StatusChip(
                            ChipStyle(
                              settings.vibrationEnabled
                                  ? 'Vibration on'
                                  : 'Vibration off',
                              RadiantColors.disabled,
                              Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Signals ahead may flash yellow as a warning. The '
                        'emergency vehicle may pass through on its own.',
                        style: TextStyle(
                          fontSize: 12,
                          color: RadiantColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: RadiantColors.green,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Got it',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
