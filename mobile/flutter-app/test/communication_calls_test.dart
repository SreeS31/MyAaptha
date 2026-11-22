import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/communication_call_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final session = AuthTokenBundle(
      tokenType: 'Bearer',
      accessToken: 'fixture',
      refreshToken: 'fixture',
      expiresIn: 900);
  test(
      'native direct and circle calls share authenticated room and signaling endpoints',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer fixture');
      if (request.method == 'GET' &&
          (request.url.path.endsWith('/history') ||
              request.url.path.endsWith('/signals') ||
              request.url.path.endsWith('/meetings'))) {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(
          jsonEncode({
            'id': 'room-fixture',
            'scope': 'CIRCLE',
            'targetId': 9,
            'callType': 'VIDEO'
          }),
          200,
          headers: {'content-type': 'application/json'});
    });
    final api = MyAapthaApi(session,
        client: ApiClient(baseUrl: 'https://example.test', httpClient: client));
    await api.communicationCalls();
    await api.communicationCallHistory();
    await api.createCommunicationCall('CIRCLE', 9, 'VIDEO');
    await api.joinCommunicationCall('room-fixture');
    await api.sendCommunicationSignal('room-fixture', 2, 'offer',
        jsonEncode({'type': 'offer', 'sdp': 'synthetic'}));
    await api.communicationSignals('room-fixture', 3);
    await api.leaveCommunicationCall('room-fixture', everyone: true);
    expect(jsonDecode(requests[2].body),
        {'scope': 'CIRCLE', 'targetId': 9, 'callType': 'VIDEO'});
    expect(jsonDecode(requests[4].body)['recipientId'], 2);
    expect(requests[5].url.queryParameters['after'], '3');
    expect(requests.last.url.path, '/api/network/meetings/room-fixture/end');
    client.close();
  });
  testWidgets(
      'circle call menu offers voice and video without acquiring devices before selection',
      (tester) async {
    final api = MyAapthaApi(session);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CommunicationCallButton(
                api: api, scope: 'CIRCLE', target: 9))));
    await tester.tap(find.byTooltip('Call'));
    await tester.pumpAndSettle();
    expect(find.text('Voice call'), findsOneWidget);
    expect(find.text('Video call'), findsOneWidget);
    expect(CommunicationCallScreen.isOpen, false);
    expect(tester.takeException(), isNull);
  });
}
