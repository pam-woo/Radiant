import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radiant_app/features/settings/settings_view.dart';
import 'package:radiant_app/state/settings_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('settings start with sensible defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsState.fromPrefs(prefs);

    expect(settings.alertsEnabled, isTrue);
    expect(settings.soundEnabled, isTrue);
    expect(settings.vibrationEnabled, isTrue);
    expect(settings.highContrast, isFalse);
    expect(settings.colorBlindSafe, isFalse);
    expect(settings.textSize, TextSize.normal);
  });

  test('settings are saved and restored', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsState.fromPrefs(prefs);

    await settings.setHighContrast(true);
    await settings.setTextSize(TextSize.large);
    await settings.setAlertsEnabled(false);

    final restored = SettingsState.fromPrefs(prefs);
    expect(restored.highContrast, isTrue);
    expect(restored.textSize, TextSize.large);
    expect(restored.alertsEnabled, isFalse);
  });

  test('text sizes scale as expected', () {
    expect(TextSize.small.factor, lessThan(1.0));
    expect(TextSize.normal.factor, 1.0);
    expect(TextSize.large.factor, greaterThan(1.0));
  });

  testWidgets('tapping a row toggles its setting', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsState.fromPrefs(prefs);

    await tester.pumpWidget(
      SettingsScope(
        settings: settings,
        child: MaterialApp(
          home: Scaffold(
            body: SettingsView(
              driver: false,
              actionLabel: 'Sign out',
              onAction: () async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('High-contrast mode'));
    await tester.pump();
    expect(settings.highContrast, isTrue);

    await tester.tap(find.text('A+'));
    await tester.pump();
    expect(settings.textSize, TextSize.large);
  });
}
