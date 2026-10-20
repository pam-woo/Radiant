import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../data/radiant_repository.dart';
import '../../state/app_state.dart';
import '../../widgets/placeholder_page.dart';
import '../driver/driver_emergency_banner.dart';
import '../driver/emergency_alert_screen.dart';
import '../event_log/event_log_view.dart';

/// Driver home: Event Log (with the emergency banner) and Settings. A new
/// emergency vehicle opens the full-screen alert automatically.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key, required this.appState, required this.repo});

  final AppState appState;
  final RadiantRepository repo;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  static const _titles = ['Event Log', 'Settings'];
  int _index = 0;

  // Intersections whose current emergency already opened the alert.
  final Set<int> _handled = {};
  bool _alertOpen = false;

  @override
  void initState() {
    super.initState();
    widget.repo.start(includeLive: false);
    widget.repo.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepoChanged);
    widget.repo.stop();
    super.dispose();
  }

  void _onRepoChanged() {
    if (!mounted) return;

    final active = widget.repo.activeEmergencies;
    final ids = {for (final a in active) a.intersectionId};
    // Forget finished emergencies so a later one alerts again.
    _handled.removeWhere((id) => !ids.contains(id));

    if (_alertOpen || widget.repo.offline) return;
    for (final alert in active) {
      if (_handled.add(alert.intersectionId)) {
        _openAlert(alert);
        break;
      }
    }
  }

  Future<void> _openAlert(ActiveEmergency alert) async {
    _alertOpen = true;
    _buzz();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmergencyAlertScreen(repo: widget.repo, initial: alert),
      ),
    );
    _alertOpen = false;
  }

  /// Basic haptic feedback. Proper alert sound and vibration come with the
  /// notification setup.
  Future<void> _buzz() async {
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.click);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      EventLogView(
        repo: widget.repo,
        banner: DriverEmergencyBanner(repo: widget.repo),
      ),
      SettingsPlaceholder(
        actionLabel: 'Switch user type',
        onAction: widget.appState.clearRole,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list),
            label: 'Event Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
