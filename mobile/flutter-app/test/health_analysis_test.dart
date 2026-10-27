import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/health_analysis_card.dart';

AuthTokenBundle session() => AuthTokenBundle(
    tokenType: 'Bearer',
    accessToken: 'fixture',
    refreshToken: 'fixture',
    expiresIn: 900);

class AnalysisApi extends MyAapthaApi {
  AnalysisApi() : super(session());
  bool enabled = true, fail = false;
  int uploads = 0;
  @override
  Future<Map<String, dynamic>> healthAnalysisPolicy() async {
    if (fail) throw const MyAapthaApiException('Unavailable');
    return {
      'configured': enabled,
      'provider': 'OpenAI',
      'consentRequired': true
    };
  }

  @override
  Future<void> analyzeHealthReport(Uint8List bytes, String name,
      {required bool processingConsent}) async {
    expect(processingConsent, true);
    uploads++;
  }
}

void main() {
  testWidgets('requires consent and clears it after each upload',
      (tester) async {
    final api = AnalysisApi();
    var saved = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HealthAnalysisCard(
                api: api,
                onSaved: () async {
                  saved++;
                },
                selectReport: () async => PlatformFile(
                    name: 'fixture.pdf',
                    size: 10,
                    bytes: Uint8List.fromList([37, 80, 68, 70]))))));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Analyze report'));
    await tester.pumpAndSettle();
    expect(api.uploads, 1);
    expect(saved, 1);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false);
  });
  testWidgets(
      'disabled or failed policy never enables upload and permits retry',
      (tester) async {
    final api = AnalysisApi()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HealthAnalysisCard(api: api, onSaved: () async {}))));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    api.fail = false;
    api.enabled = false;
    await tester.tap(find.text('Check availability'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(api.uploads, 0);
  });
  test('native multipart carries consent and MIME; missing consent never sends',
      () async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.retentionChooser = (_) async =>
        throw StateError('Analysis must not ask for stored-file retention');
    addTearDown(() => ApiClient.retentionChooser = null);
    var calls = 0;
    final api = MyAapthaApi(session(),
        client: ApiClient(
            baseUrl: 'http://localhost:8080',
            httpClient: MockClient((request) async {
              calls++;
              expect(request.url.path, '/api/health/reports/analyze');
              expect(request.headers['Authorization'], 'Bearer fixture');
              expect(request.body, contains('name="processingConsent"'));
              expect(request.body, contains('application/pdf'));
              return http.Response('{}', 200);
            })));
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.4\nsynthetic'));
    await expectLater(
        api.analyzeHealthReport(bytes, 'fixture.pdf', processingConsent: false),
        throwsFormatException);
    expect(calls, 0);
    await api.analyzeHealthReport(bytes, 'fixture.pdf',
        processingConsent: true);
    expect(calls, 1);
  });
}
