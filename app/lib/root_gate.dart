import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/radiant_repository.dart';
import 'features/auth/notification_permission_screen.dart';
import 'features/auth/select_user_type_screen.dart';
import 'features/shell/admin_shell.dart';
import 'features/shell/driver_shell.dart';
import 'state/app_state.dart';

/// Decides which screen to show from the chosen role and the login session.
class RootGate extends StatelessWidget {
  const RootGate({super.key, required this.appState, required this.repo});

  final AppState appState;
  final RadiantRepository repo;

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final signedIn = auth.currentSession != null;

            switch (appState.role) {
              case UserRole.admin:
                return signedIn
                    ? AdminShell(appState: appState, repo: repo)
                    : SelectUserTypeScreen(appState: appState);
              case UserRole.driver:
                return appState.notificationPromptDone
                    ? DriverShell(appState: appState, repo: repo)
                    : NotificationPermissionScreen(appState: appState);
              case null:
                return SelectUserTypeScreen(appState: appState);
            }
          },
        );
      },
    );
  }
}
