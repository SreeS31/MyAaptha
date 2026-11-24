import 'package:flutter/material.dart';
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
