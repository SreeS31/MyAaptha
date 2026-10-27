import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/health_report_dialog.dart';

class ReportApi extends MyAapthaApi {
  ReportApi()
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'fixture',
            refreshToken: 'fixture',
            expiresIn: 900));
  int calls = 0;
  bool fail = false;
  Completer<void>? pending;
  Map<String, dynamic>? saved;
  @override
  Future<void> addHealthReport(Map<String, dynamic> value) async {
    calls++;
    saved = value;
    if (fail) {
      throw const MyAapthaApiException('Synthetic save failed');
    }
    await pending?.future;
  }
}

Future<void> open(WidgetTester tester, ReportApi api) async {
  await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          HealthReportDialog(api: api, documents: const [])),
                  child: const Text('Open entry'))))));
  await tester.tap(find.text('Open entry'));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label);
Future<void> fill(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), value);
  await tester.pump();
}

Future<void> first(WidgetTester tester) async {
  await fill(tester, 'Report name', 'Synthetic report');
  await fill(tester, 'Metric 1', 'Synthetic marker');
  await fill(tester, 'Value 1', '0');
  await fill(tester, 'Unit 1', 'u');
}

void main() {
  testWidgets('validates blank entries and reference order before any save',
      (tester) async {
    final api = ReportApi();
    await open(tester, api);
    await tester.tap(find.text('Save report'));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
    expect(find.text('Required'), findsWidgets);
    await first(tester);
    await fill(tester, 'Lab minimum 1', '3');
    await fill(tester, 'Lab maximum 1', '2');
    await tester.tap(find.text('Save report'));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
    expect(find.text('Minimum cannot exceed maximum'), findsOneWidget);
    await fill(tester, 'Lab minimum 1', '0');
    await tester.tap(find.text('Save report'));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect((api.saved!['measurements'] as List).single['value'], 0);
    expect(find.byType(HealthReportDialog), findsNothing);
  });
  testWidgets(
      'keeps all draft values after failure and supports retry with multiple rows',
      (tester) async {
    final api = ReportApi()..fail = true;
    await open(tester, api);
    await first(tester);
    await tester.ensureVisible(find.text('Add measurement'));
    await tester.tap(find.text('Add measurement'));
    await tester.pumpAndSettle();
    await fill(tester, 'Metric 2', 'Second marker');
    await fill(tester, 'Value 2', '12.5');
    await fill(tester, 'Unit 2', 'v');
    await tester.tap(find.text('Save report'));
    await tester.pumpAndSettle();
    expect(find.byType(HealthReportDialog), findsOneWidget);
    expect(find.text('Synthetic save failed').hitTestable(), findsOneWidget);
    expect(tester.widget<TextField>(field('Report name')).controller!.text,
        'Synthetic report');
    expect(tester.widget<TextField>(field('Value 2')).controller!.text, '12.5');
    api.fail = false;
    await tester.tap(find.text('Save report'));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    expect(api.saved!['measurements'], hasLength(2));
    expect(api.saved!['collectedOn'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });
  testWidgets('prevents duplicate submits and permits safe row removal',
      (tester) async {
    final api = ReportApi()..pending = Completer<void>();
    await open(tester, api);
    await first(tester);
    await tester.ensureVisible(find.text('Add measurement'));
    await tester.tap(find.text('Add measurement'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Remove measurement 2'));
    await tester.tap(find.byTooltip('Remove measurement 2'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Save report'));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull);
    api.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HealthReportDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
