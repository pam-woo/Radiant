import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TextSize { small, normal, large }

extension TextSizeInfo on TextSize {
  double get factor => switch (this) {
        TextSize.small => 0.9,
        TextSize.normal => 1.0,
        TextSize.large => 1.2,
      };
}

/// User settings, saved on the device and applied across the whole app.
class SettingsState extends ChangeNotifier {
  SettingsState._(SharedPreferences prefs)
      : _prefs = prefs,
        _alertsEnabled = prefs.getBool(_kAlerts) ?? true,
        _soundEnabled = prefs.getBool(_kSound) ?? true,
        _vibrationEnabled = prefs.getBool(_kVibration) ?? true,
        _highContrast = prefs.getBool(_kContrast) ?? false,
        _colorBlindSafe = prefs.getBool(_kColorBlind) ?? false,
        _textSize = _readTextSize(prefs);

  factory SettingsState.fromPrefs(SharedPreferences prefs) =>
      SettingsState._(prefs);

  static const _kAlerts = 'settings_alerts';
  static const _kSound = 'settings_sound';
  static const _kVibration = 'settings_vibration';
  static const _kContrast = 'settings_high_contrast';
  static const _kColorBlind = 'settings_color_blind_safe';
  static const _kTextSize = 'settings_text_size';

  final SharedPreferences _prefs;
  bool _alertsEnabled;
  bool _soundEnabled;
  bool _vibrationEnabled;
  bool _highContrast;
  bool _colorBlindSafe;
  TextSize _textSize;

  static TextSize _readTextSize(SharedPreferences prefs) {
    switch (prefs.getString(_kTextSize)) {
      case 'small':
        return TextSize.small;
      case 'large':
        return TextSize.large;
      default:
        return TextSize.normal;
    }
  }

  bool get alertsEnabled => _alertsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get highContrast => _highContrast;
  bool get colorBlindSafe => _colorBlindSafe;
  TextSize get textSize => _textSize;

  Future<void> setAlertsEnabled(bool value) async {
    _alertsEnabled = value;
    notifyListeners();
    await _prefs.setBool(_kAlerts, value);
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    await _prefs.setBool(_kSound, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    notifyListeners();
    await _prefs.setBool(_kVibration, value);
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    notifyListeners();
    await _prefs.setBool(_kContrast, value);
  }

  Future<void> setColorBlindSafe(bool value) async {
    _colorBlindSafe = value;
    notifyListeners();
    await _prefs.setBool(_kColorBlind, value);
  }

  Future<void> setTextSize(TextSize value) async {
    _textSize = value;
    notifyListeners();
    await _prefs.setString(_kTextSize, value.name);
  }
}

/// Makes the settings available to every screen. Widgets that read them with
/// [SettingsScope.of] rebuild when a setting changes.
class SettingsScope extends InheritedNotifier<SettingsState> {
  const SettingsScope({
    super.key,
    required SettingsState settings,
    required super.child,
  }) : super(notifier: settings);

  /// Use inside build methods (rebuilds when settings change).
  static SettingsState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found above this widget');
    return scope!.notifier!;
  }

  /// Use in callbacks and listeners (no rebuild dependency).
  static SettingsState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found above this widget');
    return scope!.notifier!;
  }
}
