import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/radiant_logo.dart';
import 'login_screen.dart';

/// First screen: choose between authorized user and driver.
class SelectUserTypeScreen extends StatelessWidget {
  const SelectUserTypeScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RadiantLogo(),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to Radiant',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose how you want to use the app.',
                  style: TextStyle(color: RadiantColors.textMuted),
                ),
                const SizedBox(height: 20),
                _RoleCard(
                  title: 'Authorized user',
                  body: 'Admins and emergency vehicle personnel. Login '
                      'required. Full access to the live monitor, event log '
                      'and settings.',
                  action: 'Sign in >',
                  highlighted: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LoginScreen(appState: appState),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _RoleCard(
                  title: 'Driver',
                  body: 'No login needed. See the event log summary and get '
                      'alerts when an emergency vehicle is approaching.',
                  action: 'Continue as driver >',
                  highlighted: false,
                  onTap: () => appState.setRole(UserRole.driver),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Radiant for Android',
                  style: TextStyle(fontSize: 11, color: RadiantColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.body,
    required this.action,
    required this.highlighted,
    required this.onTap,
  });

  final String title;
  final String body;
  final String action;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RadiantColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: highlighted
              ? RadiantColors.maroonBright
              : RadiantColors.surfaceBorder,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  color: RadiantColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: highlighted
                      ? RadiantColors.maroon
                      : RadiantColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  action,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
