import 'dart:convert';

import 'package:circlenet_mobile/features/auth/models/auth_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const String _sessionKey = 'auth_session';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<void> save(AuthTokenBundle tokenBundle) async {
    final payload = jsonEncode({
      'tokenType': tokenBundle.tokenType,
      'accessToken': tokenBundle.accessToken,
      'refreshToken': tokenBundle.refreshToken,
      'expiresIn': tokenBundle.expiresIn,
    });
    await _secureStorage.write(key: _sessionKey, value: payload);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<AuthTokenBundle?> load() async {
    String? payload = await _secureStorage.read(key: _sessionKey);
    if (payload == null || payload.isEmpty) {
      // One-time migration from releases that used unencrypted preferences.
      final prefs = await SharedPreferences.getInstance();
      payload = prefs.getString(_sessionKey);
      if (payload != null && payload.isNotEmpty) {
        await _secureStorage.write(key: _sessionKey, value: payload);
        await prefs.remove(_sessionKey);
      }
    }
    if (payload == null || payload.isEmpty) {
      return null;
    }

    final data = jsonDecode(payload);
    if (data is! Map<String, dynamic>) {
      return null;
    }

    return AuthTokenBundle.fromJson(data);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _sessionKey);
    await prefs.remove(_sessionKey);
  }
}
