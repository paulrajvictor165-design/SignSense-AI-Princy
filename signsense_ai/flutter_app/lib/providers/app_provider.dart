import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SignSense AI — App-level state provider.
///
/// Phase F: Connectivity auto-detection wired using [connectivity_plus].
/// [isOnline] is updated automatically when the network changes.
/// [offlineMode] is the *user-controlled* override (manual toggle).
/// Screens should check `offlineMode || !isOnline` for true offline state.
class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  double _textScaleFactor = 1.2;
  bool _highContrastMode = false;
  bool _hapticFeedback = true;
  String _language = 'en-IN';
  double _speechRate = 0.5;
  double _speechVolume = 1.0;
  double _speechPitch = 1.0;
  bool _isFirstLaunch = true;
  bool _offlineMode = false;
  String _emergencyContact = '';

  // ── Connectivity (auto-detected) ──────────────────────────────────────────
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  ThemeMode get themeMode => _themeMode;
  double get textScaleFactor => _textScaleFactor;
  bool get highContrastMode => _highContrastMode;
  bool get hapticFeedback => _hapticFeedback;
  String get language => _language;
  double get speechRate => _speechRate;
  double get speechVolume => _speechVolume;
  double get speechPitch => _speechPitch;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get offlineMode => _offlineMode;
  String get emergencyContact => _emergencyContact;

  /// True when the device has an active internet connection.
  /// Updated automatically via [connectivity_plus].
  bool get isOnline => _isOnline;

  /// True when the user should be treated as offline — either because
  /// they manually enabled offline mode OR because connectivity is lost.
  bool get effectivelyOffline => _offlineMode || !_isOnline;

  AppProvider() {
    _loadPreferences();
    _initConnectivity();
  }

  // ── Connectivity ──────────────────────────────────────────────────────────

  Future<void> _initConnectivity() async {
    // Check initial state
    final result = await Connectivity().checkConnectivity();
    _updateConnectivity(result);

    // Subscribe to changes
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen(_updateConnectivity);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = prefs.getBool('darkMode') ?? true ? ThemeMode.dark : ThemeMode.light;
    _textScaleFactor = prefs.getDouble('textScaleFactor') ?? 1.2;
    _highContrastMode = prefs.getBool('highContrastMode') ?? false;
    _hapticFeedback = prefs.getBool('hapticFeedback') ?? true;
    _language = prefs.getString('language') ?? 'en-IN';
    _speechRate = prefs.getDouble('speechRate') ?? 0.5;
    _speechVolume = prefs.getDouble('speechVolume') ?? 1.0;
    _speechPitch = prefs.getDouble('speechPitch') ?? 1.0;
    _isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    _offlineMode = prefs.getBool('offlineMode') ?? false;
    _emergencyContact = prefs.getString('emergencyContact') ?? '';
    notifyListeners();
  }

  Future<void> setThemeMode(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDark);
    notifyListeners();
  }

  Future<void> setTextScaleFactor(double scale) async {
    _textScaleFactor = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('textScaleFactor', scale);
    notifyListeners();
  }

  Future<void> setHighContrastMode(bool value) async {
    _highContrastMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('highContrastMode', value);
    notifyListeners();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speechRate', rate);
    notifyListeners();
  }

  Future<void> setSpeechVolume(double volume) async {
    _speechVolume = volume;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('speechVolume', volume);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  Future<void> setFirstLaunchComplete() async {
    _isFirstLaunch = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    notifyListeners();
  }

  Future<void> setOfflineMode(bool value) async {
    _offlineMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offlineMode', value);
    notifyListeners();
  }

  Future<void> setEmergencyContact(String contact) async {
    _emergencyContact = contact;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergencyContact', contact);
    notifyListeners();
  }
}
