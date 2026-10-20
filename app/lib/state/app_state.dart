import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserRole { admin, driver }

/// Small app-wide state kept on the device: which role was chosen and whether
/// the driver has already seen the notification permission screen.
class AppState extends ChangeNotifier {
  AppState._(SharedPreferences prefs)
      : _prefs = prefs,
        _role = _readRole(prefs),
        _notificationPromptDone = prefs.getBool(_kPrompted) ?? false;

  static const _kRole = 'role';
  static const _kPrompted = 'notification_prompt_done';

  final SharedPreferences _prefs;
  UserRole? _role;
  bool _notificationPromptDone;

  static Future<AppState> load() async =>
      AppState._(await SharedPreferences.getInstance());

  static UserRole? _readRole(SharedPreferences prefs) {
    switch (prefs.getString(_kRole)) {
      case 'admin':
        return UserRole.admin;
      case 'driver':
        return UserRole.driver;
      default:
        return null;
    }
  }

  UserRole? get role => _role;
  bool get notificationPromptDone => _notificationPromptDone;

  Future<void> setRole(UserRole role) async {
    _role = role;
    await _prefs.setString(_kRole, role.name);
    notifyListeners();
  }

  Future<void> clearRole() async {
    _role = null;
    await _prefs.remove(_kRole);
    notifyListeners();
  }

  Future<void> markNotificationPromptDone() async {
    _notificationPromptDone = true;
    await _prefs.setBool(_kPrompted, true);
    notifyListeners();
  }
}
