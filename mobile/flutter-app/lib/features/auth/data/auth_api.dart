import 'package:myaaptha_mobile/core/config/app_config.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';

class AuthApi {
  AuthApi({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _apiClient;

  Future<AuthHealth> checkHealth() async {
    final response = await _apiClient.get(AppConfig.authHealthPath);
    if (!response.isSuccess) {
      throw AuthApiException(
        'Auth health check failed with status ${response.statusCode}',
      );
    }

    return AuthHealth(status: response.body.trim());
  }

  Future<AuthTokenBundle> login(LoginRequest request) async {
    final response =
        await _apiClient.post(AppConfig.authLoginPath, request.toJson());
    if (!response.isSuccess) {
      throw AuthApiException(_message(response, 'Login failed'));
    }

    final data = response.decodeJson();
    if (data is! Map<String, dynamic>) {
      throw const AuthApiException('Invalid login response payload');
    }

    return AuthTokenBundle.fromJson(data);
  }

  String _message(ApiResponse response, String fallback) {
    try {
      final body = response.decodeJson();
      if (body is Map && body['message'] != null) return body['message'].toString();
    } catch (_) {}
    return '$fallback with status ${response.statusCode}';
  }

  Future<AuthTokenBundle> refresh(RefreshRequest request) async {
    final response =
        await _apiClient.post(AppConfig.authRefreshPath, request.toJson());
    if (!response.isSuccess) {
      throw AuthApiException(
        'Refresh failed with status ${response.statusCode}',
      );
    }

    final data = response.decodeJson();
    if (data is! Map<String, dynamic>) {
      throw const AuthApiException('Invalid refresh response payload');
    }

    return AuthTokenBundle.fromJson(data);
  }

  Future<void> logout(RefreshRequest request) async {
    final response =
        await _apiClient.post(AppConfig.authLogoutPath, request.toJson());
    if (!response.isSuccess) {
      throw AuthApiException(
        'Logout failed with status ${response.statusCode}',
      );
    }
  }

  Future<void> revoke(RefreshRequest request) async {
    final response =
        await _apiClient.post(AppConfig.authRevokePath, request.toJson());
    if (!response.isSuccess) {
      throw AuthApiException(
        'Revoke failed with status ${response.statusCode}',
      );
    }
  }

  Future<DashboardSummary> fetchDashboardSummary(String accessToken) async {
    final response = await _apiClient.get(
      AppConfig.dashboardSummaryPath,
      bearerToken: accessToken,
    );
    if (!response.isSuccess) {
      throw AuthApiException(
        'Dashboard summary failed with status ${response.statusCode}',
      );
    }

    final data = response.decodeJson();
    if (data is! Map<String, dynamic>) {
      throw const AuthApiException('Invalid dashboard summary payload');
    }

    return DashboardSummary.fromJson(data);
  }

  Future<RegisterUserResult> registerUser(RegisterUserRequest request) async {
    final response =
        await _apiClient.post(AppConfig.usersPath, request.toJson());

    if (!response.isSuccess) {
      throw AuthApiException(
        'User registration failed with status ${response.statusCode}',
      );
    }

    final data = response.decodeJson();
    if (data is! Map<String, dynamic>) {
      throw const AuthApiException('Invalid registration response payload');
    }

    return RegisterUserResult.fromJson(data);
  }
}

class AuthApiException implements Exception {
  const AuthApiException(this.message);

  final String message;

  @override
  String toString() => 'AuthApiException: $message';
}
