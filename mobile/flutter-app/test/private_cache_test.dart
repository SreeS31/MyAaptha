import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('removes old plaintext caches and never persists new private responses',
      () async {
    SharedPreferences.setMockInitialValues(
        {'api_cache_old': 'private health data', 'theme': 'dark'});
    final client = ApiClient(
        baseUrl: 'http://localhost:8080',
        httpClient: MockClient(
            (_) async => http.Response('{"private":"contact"}', 200)));
    expect(
        (await client.get('/api/network/relationships', bearerToken: 'test'))
            .isSuccess,
        isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getKeys().where((key) => key.startsWith('api_cache_')), isEmpty);
    expect(prefs.getString('theme'), 'dark');
  });
  test('offline requests cannot replay cached private data', () async {
    SharedPreferences.setMockInitialValues({'api_cache_old': 'private'});
    final client = ApiClient(
        baseUrl: 'http://localhost:8080',
        httpClient:
            MockClient((_) async => throw const SocketException('offline')));
    await expectLater(
        client.get('/api/network/relationships', bearerToken: 'test'),
        throwsA(isA<SocketException>()));
  });
}
