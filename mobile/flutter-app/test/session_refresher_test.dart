import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/features/auth/data/session_refresher.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';

AuthTokenBundle bundle(String suffix, int lifetime) => AuthTokenBundle(
    tokenType: 'Bearer', accessToken: 'access-$suffix',
    refreshToken: 'refresh-$suffix', expiresIn: lifetime);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fresh sessions make no refresh request', () async {
    final refresher = SessionRefresher(refresh: (_) async => throw StateError('unexpected'), persist: (_) async {});
    expect(await refresher.accessToken(bundle('fresh', 900)), 'access-fresh');
  });

  test('concurrent requests share one rotation and update the shared bundle', () async {
    final session = bundle('old', 0);
    final response = Completer<AuthTokenBundle>();
    var requests = 0, saves = 0;
    final refresher = SessionRefresher(refresh: (token) {
      expect(token, 'refresh-old'); requests++; return response.future;
    }, persist: (value) async { saves++; expect(value.refreshToken, 'refresh-new'); });
    final pending = List.generate(20, (_) => refresher.accessToken(session));
    response.complete(bundle('new', 900));
    expect(await Future.wait(pending), everyElement('access-new'));
    expect(requests, 1); expect(saves, 1);
    expect(session.refreshToken, 'refresh-new');
    expect(await refresher.accessToken(session), 'access-new');
    expect(requests, 1);
  });

  test('failed rotation releases the pending operation without changing tokens', () async {
    final session = bundle('old', 0);
    var attempts = 0;
    final refresher = SessionRefresher(refresh: (_) {
      if (++attempts == 1) throw StateError('offline');
      return Future.value(bundle('new', 900));
    }, persist: (_) async {});
    await expectLater(refresher.accessToken(session), throwsStateError);
    expect(session.refreshToken, 'refresh-old');
    expect(await refresher.accessToken(session), 'access-new');
  });

  test('all authenticated request types use refreshed authorization', () async {
    SharedPreferences.setMockInitialValues({});
    var requests = 0;
    final client = ApiClient(baseUrl: 'http://localhost:8080',
        accessTokenProvider: () async => 'fresh',
        httpClient: MockClient((request) async {
          requests++; expect(request.headers['Authorization'], 'Bearer fresh');
          return http.Response('{}', 200);
        }));
    await client.get('/api/profile/me', bearerToken: 'old');
    await client.post('/api/network/presence/heartbeat', {}, bearerToken: 'old');
    await client.put('/api/settings/me', {}, bearerToken: 'old');
    await client.delete('/api/finance/transactions/1', bearerToken: 'old');
    await client.postMultipart('/api/network/circles/1/posts', {'message': 'hello'}, bearerToken: 'old');
    expect(requests, 5);
  });

  test('public authentication requests do not recursively refresh', () async {
    final client = ApiClient(baseUrl: 'http://localhost:8080',
        accessTokenProvider: () async => throw StateError('unexpected refresh'),
        httpClient: MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response('{}', 200);
        }));
    expect((await client.post('/api/auth/refresh', {'refreshToken': 'test'})).isSuccess, isTrue);
  });
}
