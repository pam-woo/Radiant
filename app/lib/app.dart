import 'package:flutter/material.dart';

import 'data/radiant_repository.dart';
import 'root_gate.dart';
import 'state/app_state.dart';
import 'state/settings_state.dart';
import 'theme.dart';

class RadiantApp extends StatelessWidget {
  const RadiantApp({
    super.key,
    required this.appState,
    required this.repo,
    required this.settings,
  });

  final AppState appState;
  final RadiantRepository repo;
  final SettingsState settings;

  // High-contrast mode: brightens dim text, borders and signal colors.
  static const _boost = ColorFilter.matrix(<double>[
    1.4, 0, 0, 0, 0, //
    0, 1.4, 0, 0, 0, //
    0, 0, 1.4, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'Radiant',
          debugShowCheckedModeBanner: false,
          theme: buildRadiantTheme(highContrast: settings.highContrast),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final system = media.textScaler.scale(1.0);

            Widget content = MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  system * settings.textSize.factor,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
            if (settings.highContrast) {
              content = ColorFiltered(colorFilter: _boost, child: content);
            }
            return SettingsScope(settings: settings, child: content);
          },
          home: RootGate(appState: appState, repo: repo),
        );
      },
    );
  }
}

/// Shown instead of crashing when the Supabase settings were not provided.
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildRadiantTheme(),
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Radiant is missing its Supabase settings.\n\n'
                'Copy env.example.json to env.json, fill it in, and run:\n'
                'flutter run --dart-define-from-file=env.json',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
