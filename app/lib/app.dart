import 'package:flutter/material.dart';

import 'data/radiant_repository.dart';
import 'root_gate.dart';
import 'state/app_state.dart';
import 'theme.dart';

class RadiantApp extends StatelessWidget {
  const RadiantApp({super.key, required this.appState, required this.repo});

  final AppState appState;
  final RadiantRepository repo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radiant',
      debugShowCheckedModeBanner: false,
      theme: buildRadiantTheme(),
      home: RootGate(appState: appState, repo: repo),
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
