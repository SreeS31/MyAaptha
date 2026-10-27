import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _configuredApiBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (kReleaseMode) {
      final uri = Uri.tryParse(_configuredApiBaseUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
        throw StateError('Release builds require an HTTPS API_BASE_URL.');
      }
    }
    if (_configuredApiBaseUrl.isNotEmpty) return _configuredApiBaseUrl;
    // Android emulators expose the host machine through 10.0.2.2. iOS
    // simulators can use localhost. Physical devices should pass API_BASE_URL.
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080';
  }

  static const String authHealthPath = '/api/auth/health';
  static const String authLoginPath = '/api/auth/login';
  static const String authRefreshPath = '/api/auth/refresh';
  static const String authLogoutPath = '/api/auth/logout';
  static const String authRevokePath = '/api/auth/revoke';
  static const String usersPath = '/api/users';
  static const String dashboardSummaryPath = '/api/dashboard/summary';
}
