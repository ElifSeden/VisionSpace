import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized backend URL configuration.
///
/// Resolution order:
/// 1. Saved Profile setting (`backend_base_url`).
/// 2. Compile-time define: `--dart-define=BACKEND_BASE_URL=https://...`.
/// 3. Platform-aware local development default.
class BackendConfig {
  BackendConfig._();

  static final BackendConfig instance = BackendConfig._();

  static const _prefKey = 'backend_base_url';
  static const _definedUrl = String.fromEnvironment('BACKEND_BASE_URL');
  static const _androidEmulatorUrl = 'http://10.0.2.2:8000';
  static const _localhostUrl = 'http://localhost:8000';

  String _baseUrl = _defaultUrl;

  String get baseUrl => _baseUrl;

  static String get _defaultUrl {
    if (_definedUrl.trim().isNotEmpty) return _normalize(_definedUrl);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _androidEmulatorUrl;
    }
    return _localhostUrl;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = _normalize(prefs.getString(_prefKey) ?? _defaultUrl);
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = _normalize(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _baseUrl);
  }

  /// Reset to the platform-aware default URL.
  Future<void> reset() => setBaseUrl(_defaultUrl);

  static String _normalize(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return _localhostUrl;
    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    return withScheme.endsWith('/')
        ? withScheme.substring(0, withScheme.length - 1)
        : withScheme;
  }
}
