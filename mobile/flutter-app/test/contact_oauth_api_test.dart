import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';

class OAuthResponseClient extends ApiClient {
  OAuthResponseClient(this.response) : super(baseUrl: 'http://unused');
  final Object response;
  int calls = 0;
  @override
  Future<ApiResponse> get(String path, {String? bearerToken}) async {
    calls++;
    final body = jsonEncode(response);
    return ApiResponse(
        statusCode: 200,
        body: body,
        bodyBytes: Uint8List.fromList(utf8.encode(body)));
  }
}

void main() {
  MyAapthaApi api(OAuthResponseClient client) => MyAapthaApi(
      AuthTokenBundle(
          tokenType: 'Bearer',
          accessToken: 'fixture',
          refreshToken: 'fixture',
          expiresIn: 900),
      client: client);
  test('legacy failure payload is a terminal 422 rather than a list-cast error',
      () async {
    final client = OAuthResponseClient(
        {'status': 'failed', 'message': 'Contact access was denied'});
    await expectLater(
        api(client).contactOAuthResult('fixture'),
        throwsA(isA<MyAapthaApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.message, 'message', contains('denied'))));
    expect(client.calls, 1);
  });
  test('empty completed result remains a successful list', () async {
    final client = OAuthResponseClient(<Object>[]);
    expect(await api(client).contactOAuthResult('fixture'), isEmpty);
  });
  test('malformed result is rejected without polling forever', () async {
    final client = OAuthResponseClient({'unexpected': 'payload'});
    await expectLater(
        api(client).contactOAuthResult('fixture'),
        throwsA(isA<MyAapthaApiException>()
            .having((e) => e.statusCode, 'status', 502)));
    expect(client.calls, 1);
  });
}
