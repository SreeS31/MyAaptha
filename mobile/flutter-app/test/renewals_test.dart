import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/renewals_screen.dart';

AuthTokenBundle session() => AuthTokenBundle(
    tokenType: 'Bearer',
    accessToken: 'test-token',
    refreshToken: 'test',
    expiresIn: 900);

class RenewalApi extends MyAapthaApi {
  RenewalApi() : super(session());
  final rows = <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> renewals() async =>
      rows.map((r) => Map<String, dynamic>.from(r)).toList();
  @override
  Future<Map<String, dynamic>> saveRenewal(Map<String, dynamic> value,
      {int? id}) async {
    final row = {
      ...value,
      'id': id ?? 1,
      'daysRemaining': 15,
      'status': 'DUE_SOON',
      'nextReminderAt': '2027-01-01T03:30:00Z',
      'attachmentName': null,
      'attachmentUrl': null
    };
    rows.removeWhere((r) => r['id'] == id);
    rows.add(row);
    return row;
  }

  @override
  Future<Map<String, dynamic>> setRenewalState(int id,
      {bool? archived, bool? remindersEnabled}) async {
    final current = rows.singleWhere((row) => row['id'] == id);
    if (archived != null) current['archived'] = archived;
    if (remindersEnabled != null) {
      current['remindersEnabled'] = remindersEnabled;
    }
    return current;
  }

  @override
  Future<void> deleteRenewal(int id) async {
    rows.removeWhere((row) => row['id'] == id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('native renewals use shared authenticated CRUD and multipart routes',
      () async {
    final requests = <http.Request>[];
    final api = MyAapthaApi(session(),
        client: ApiClient(
            baseUrl: 'http://127.0.0.1:8080',
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response(
                  request.method == 'GET'
                      ? '[]'
                      : request.method == 'DELETE'
                          ? ''
                          : '{"id":8}',
                  request.method == 'DELETE' ? 204 : 200);
            })));
    await api.renewals();
    await api.saveRenewal({'title': 'Plan'});
    await api.saveRenewal({
      'title': 'Renewed',
      'id': 8,
      'daysRemaining': 30,
      'attachmentName': 'invoice.pdf'
    }, id: 8);
    expect(jsonDecode(requests[2].body), {'title': 'Renewed'});
    await api.attachRenewalReceipt(
        8, Uint8List.fromList('%PDF-1.7'.codeUnits), 'invoice.pdf');
    await api.removeRenewalReceipt(8);
    await api.deleteRenewal(8);
    expect(requests.map((r) => r.method),
        ['GET', 'POST', 'PUT', 'POST', 'DELETE', 'DELETE']);
    expect(requests.map((r) => r.url.path), [
      '/api/finance/renewals',
      '/api/finance/renewals',
      '/api/finance/renewals/8',
      '/api/finance/renewals/8/attachment',
      '/api/finance/renewals/8/attachment',
      '/api/finance/renewals/8'
    ]);
    expect(
        requests
            .every((r) => r.headers['Authorization'] == 'Bearer test-token'),
        true);
    expect(latin1.decode(requests[3].bodyBytes),
        contains('filename="invoice.pdf"'));
    await expectLater(api.attachRenewalReceipt(8, Uint8List(2), 'unsafe.exe'),
        throwsFormatException);
    await expectLater(api.attachRenewalReceipt(8, Uint8List(0), 'empty.pdf'),
        throwsFormatException);
    expect(requests, hasLength(6));
  });
  testWidgets(
      'native finance supports add, pause, renewal, archive and confirmed deletion',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = RenewalApi();
    await tester.pumpWidget(MaterialApp(home: RenewalsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add bill or warranty'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextFormField, 'Title'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'), 'Insurance plan');
    tester
        .widget<TextFormField>(find.widgetWithText(TextFormField, 'Due date'))
        .controller!
        .text = '2027-12-01';
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();
    expect(api.rows.single['title'], 'Insurance plan');
    expect(api.rows.single['remindersEnabled'], true);
    await tester.ensureVisible(find.text('Edit'));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();
    expect(api.rows.single['remindersEnabled'], false);
    await tester.ensureVisible(find.text('Renew'));
    await tester.tap(find.text('Renew'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Due date'))
            .controller!
            .text,
        isEmpty);
    tester
        .widget<TextFormField>(find.widgetWithText(TextFormField, 'Due date'))
        .controller!
        .text = '2028-12-01';
    await tester.tap(find.text('Save renewal'));
    await tester.pumpAndSettle();
    expect(api.rows.single['expiresOn'], '2028-12-01');
    await tester.ensureVisible(find.text('Archive'));
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(api.rows.single['archived'], true);
    // Return to a current fixture to exercise explicit deletion confirmation.
    api.rows.single['archived'] = false;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(home: RenewalsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.rows, hasLength(1));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete item'));
    await tester.pumpAndSettle();
    expect(api.rows, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('empty form cannot save a record', (tester) async {
    final api = RenewalApi();
    await tester.pumpWidget(MaterialApp(home: RenewalsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add bill or warranty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save item'));
    await tester.pumpAndSettle();
    expect(api.rows, isEmpty);
    expect(find.text('Enter a title'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
