import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../state/app_state.dart';
import '../../theme.dart';

/// Shown once to drivers. Explains the permission, then asks Android for it.
/// The app carries on whether or not the driver allows notifications.
class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends State<NotificationPermissionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  Future<void> _ask() async {
    // Let the explanation be visible for a moment before the system dialog.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {
      // Continue even if the permission API is unavailable.
    }
    await widget.appState.markNotificationPromptDone();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: RadiantColors.maroon,
                  child: Icon(
                    Icons.notifications_none,
                    size: 36,
                    color: RadiantColors.red,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Stay alert for emergency vehicles',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text(
                  'Radiant warns you when an ambulance or fire truck is '
                  'approaching so you can give way.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RadiantColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
