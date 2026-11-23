import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/chat_workspace_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final session = AuthTokenBundle(
      tokenType: 'Bearer',
      accessToken: 'fixture',
      refreshToken: 'fixture',
      expiresIn: 900);
  testWidgets(
      'circle menu uses shared authenticated theme and favourite settings',
      (tester) async {
    final writes = <Map<String, dynamic>>[];
    var theme = 'DEFAULT';
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer fixture');
      if (request.method == 'PUT') {
        writes.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
      }
      return http.Response(
          jsonEncode({
            'favourite': false,
            'theme': request.method == 'PUT'
                ? jsonDecode(request.body)['theme'] ?? 'DEFAULT'
                : 'DEFAULT',
            'listName': '',
            'canManage': true,
            'creator': true,
            'disappearingSeconds': 0
          }),
          200,
          headers: {'content-type': 'application/json'});
    });
    final api = MyAapthaApi(session,
        client: ApiClient(baseUrl: 'https://example.test', httpClient: client));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            appBar: AppBar(actions: [
      ChatWorkspaceMenu(
          api: api,
          kind: 'CIRCLE',
          target: 9,
          onSearch: () {},
          onSelect: () {},
          onCleared: () {},
          onTheme: (value) => theme = value,
          onInfo: () {},
          onAdd: () {})
    ]))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Circle options'));
    await tester.pumpAndSettle();
    expect(find.text('Circle info'), findsOneWidget);
    expect(find.text('Add member'), findsOneWidget);
    await tester.tap(find.text('Chat theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();
    expect(writes.single, {'theme': 'OCEAN'});
    expect(theme, 'OCEAN');
    expect(tester.takeException(), isNull);
    client.close();
  });
  test('export paginates and clear and exit use independent authorized routes',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.headers['Authorization'], 'Bearer fixture');
      return http.Response(
          jsonEncode(request.method == 'GET' ? <Object>[] : {}), 200,
          headers: {'content-type': 'application/json'});
    });
    final api = MyAapthaApi(session,
        client: ApiClient(baseUrl: 'https://example.test', httpClient: client));
    await api.exportChat('CIRCLE', 9);
    await api.clearChat('CIRCLE', 9);
    await api.exitCircle(9, 2);
    expect(requests[0].url.queryParameters['before'], '9007199254740991');
    expect(requests[1].method, 'DELETE');
    expect(requests[1].url.path.endsWith('/history'), true);
    expect(jsonDecode(requests[2].body),
        {'successorId': 2, 'deleteEmptyCircle': false});
    client.close();
  });
}
