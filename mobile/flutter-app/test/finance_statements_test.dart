import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/finance_statements_screen.dart';

class ReportsApi extends MyAapthaApi {
  ReportsApi()
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'test',
            refreshToken: 'test',
            expiresIn: 900));
  String requestedPeriod = '';
  String requestedZone = '';
  @override
  Future<Map<String, dynamic>> financialReport(
      String period, String anchor, String zone) async {
    requestedPeriod = period;
    requestedZone = zone;
    return {
      'income': 1000,
      'spending': 150,
      'net': 850,
      'transfers': 200,
      'categories': {'GROCERIES': 100, 'CLOTHING': 50},
      'incomeCategories': {'SALARY': 1000},
      'timeline': <Map<String, dynamic>>[],
      'transactions': <Map<String, dynamic>>[]
    };
  }
}

void main() {
  test('statement preview does not request media storage or retention consent',
      () async {
    ApiClient.retentionChooser =
        (_) async => throw StateError('Statements are not retained as media');
    addTearDown(() => ApiClient.retentionChooser = null);
    final paths = <String>[];
    final api = MyAapthaApi(
        AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'test',
            refreshToken: 'test',
            expiresIn: 900),
        client: ApiClient(
            baseUrl: 'https://api.test',
            httpClient: MockClient((request) async {
              paths.add(request.url.path);
              expect(request.url.path, '/api/finance/statements/preview');
              expect(request.body, contains('filename="bank.csv"'));
              return http.Response(
                  '{"rows":[],"warnings":[],"currency":"INR"}', 200,
                  headers: {'content-type': 'application/json'});
            })));
    await api.previewFinancialStatement(
        Uint8List.fromList(
            'Date\tAmount\tType\n2026-02-01\t10\tDR\n'.codeUnits),
        'bank.tsv',
        'Savings',
        'DMY',
        'Asia/Kolkata');
    expect(paths, ['/api/finance/statements/preview']);
  });
  testWidgets('report periods use the shared API and keep transfers separate',
      (tester) async {
    final api = ReportsApi();
    await tester
        .pumpWidget(MaterialApp(home: FinanceStatementsScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('INR 850.00'), findsOneWidget);
    expect(
        find.text('INR 200.00 transfer movements excluded.'), findsOneWidget);
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quarterly').last);
    await tester.pumpAndSettle();
    expect(api.requestedPeriod, 'QUARTER');
    expect(api.requestedZone, 'Asia/Kolkata');
    expect(tester.takeException(), isNull);
  });
  testWidgets('statement upload needs an account label before opening files',
      (tester) async {
    final api = ReportsApi();
    await tester
        .pumpWidget(MaterialApp(home: FinanceStatementsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Choose statement and review'), 400);
    await tester.tap(find.text('Choose statement and review'));
    await tester.pumpAndSettle();
    expect(
        find.text('Add an account label first. Use the same label each time.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
