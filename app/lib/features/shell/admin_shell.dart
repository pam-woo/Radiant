import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/radiant_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/placeholder_page.dart';
import '../../widgets/status_chip.dart';
import '../event_log/event_log_view.dart';
import '../monitor/intersection_picker.dart';
import '../monitor/monitor_screen.dart';

/// Admin home: Monitor, Event Log and Settings tabs.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.appState, required this.repo});

  final AppState appState;
  final RadiantRepository repo;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  static const _titles = ['Monitor', 'Event Log', 'Settings'];
  int _index = 0;
  int _selected = 1;

  @override
  void initState() {
    super.initState();
    widget.repo.start(includeLive: true);
  }

  @override
  void dispose() {
    widget.repo.stop();
    super.dispose();
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    await widget.appState.clearRole();
  }

  Future<void> _pickIntersection() async {
    final picked =
        await showIntersectionPicker(context, widget.repo, _selected);
    if (picked != null) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      MonitorScreen(repo: widget.repo, intersectionId: _selected),
      EventLogView(
        repo: widget.repo,
        showMonitorLink: true,
        onViewMonitor: (id) => setState(() {
          _selected = id;
          _index = 0;
        }),
      ),
      SettingsPlaceholder(actionLabel: 'Sign out', onAction: _signOut),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _pickIntersection,
                style: TextButton.styleFrom(
                  backgroundColor: RadiantColors.maroonBright,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(intersectionName(_selected)),
                    const Icon(Icons.keyboard_arrow_down, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Monitor',
          ),
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
