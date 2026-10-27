import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/moderation_queue_screen.dart';

class QueueApi extends MyAapthaApi {
  QueueApi()
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'fixture',
            refreshToken: 'fixture',
            expiresIn: 900));
  bool deny = false;
  int writes = 0;
  String? notes;
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> moderationPage(
      {String status = 'OPEN', int? beforeId}) async {
    calls.add('$status:$beforeId');
    if (deny) {
      throw const MyAapthaApiException('Administrator access required',
          statusCode: 403);
    }
    return {
      'items': [
        (beforeId == null
            ? {'id': 3, 'details': 'Newest fixture'}
            : {'id': 1, 'details': 'Oldest fixture'})
          ..addAll(
              {'status': status == 'ALL' ? 'OPEN' : status, 'reason': 'SPAM'})
      ],
      'nextCursor': beforeId == null ? 3 : null
    };
  }

  @override
  Future<void> updateModerationReport(
      int id, String status, String value) async {
    writes++;
    notes = value;
  }
}

void main() {
  testWidgets('loads older reports and clears loaded content after role denial',
      (tester) async {
    final api = QueueApi();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ModerationQueueScreen(api: api))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more reports'));
    await tester.pumpAndSettle();
    expect(api.calls, ['OPEN:null', 'OPEN:3']);
    expect(find.text('Oldest fixture'), findsOneWidget);
    api.deny = true;
    await tester.tap(find.byTooltip('Refresh queue'));
    await tester.pumpAndSettle();
    expect(find.text('Newest fixture'), findsNothing);
    expect(find.text('Oldest fixture'), findsNothing);
    expect(find.textContaining('Administrator access'), findsOneWidget);
  });
  testWidgets(
      'decision cancellation does not write and saved notes are disclosed',
      (tester) async {
    final api = QueueApi();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ModerationQueueScreen(api: api))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESOLVED'));
    await tester.pumpAndSettle();
    expect(find.text('Notes visible to the reporter'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.writes, 0);
    await tester.tap(find.text('RESOLVED'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField), 'Reviewed synthetic fixture');
    await tester.tap(find.text('Save decision'));
    await tester.pumpAndSettle();
    expect(api.writes, 1);
    expect(api.notes, 'Reviewed synthetic fixture');
    expect(find.text('Newest fixture'), findsNothing);
  });
  testWidgets('status filter resets the cursor and queries the server',
      (tester) async {
    final api = QueueApi();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ModerationQueueScreen(api: api))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REVIEWING').last);
    await tester.pumpAndSettle();
    expect(api.calls.last, 'REVIEWING:null');
  });
}
