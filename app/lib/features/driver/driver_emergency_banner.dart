import 'package:flutter/material.dart';

import '../../data/radiant_repository.dart';
import '../../state/settings_state.dart';
import '../../theme.dart';
import 'emergency_alert_screen.dart';

/// Red banner at the top of the driver Event Log while an emergency vehicle
/// is approaching. Tap it to reopen the full alert.
class DriverEmergencyBanner extends StatelessWidget {
  const DriverEmergencyBanner({super.key, required this.repo});

  final RadiantRepository repo;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final alert = repo.nearestEmergency;
        // Stale data could show an alert that is long over, so hide it.
        if (alert == null ||
            repo.offline ||
            !SettingsScope.of(context).alertsEnabled) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: RadiantColors.red,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      EmergencyAlertScreen(repo: repo, initial: alert),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EMERGENCY VEHICLE APPROACHING',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alert.summary,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
