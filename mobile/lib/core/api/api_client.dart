import 'package:dio/dio.dart';

class ApiClient {
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  void setToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }
}
