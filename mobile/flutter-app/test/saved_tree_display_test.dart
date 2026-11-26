import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/saved_tree_display.dart';
import 'package:myaaptha_mobile/features/shell/presentation/reviewed_tree_canvas.dart';

class SavedApi extends MyAapthaApi {
  SavedApi()
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'test',
            refreshToken: 'test',
            expiresIn: 900));
  final requests = <String>[];
  @override
  Future<Map<String, dynamic>> reviewedTreePersonInfo(
          int id, String key) async =>
      {
        'phones': ['+911111111111'],
        'emails': ['person@example.test'],
        'organization': 'Example Lab',
        'groups': ['College'],
        'contactAvailable': true
      };
  @override
  Future<Map<String, dynamic>> reviewedRelationshipTree(String key,
      {bool saved = false}) async {
    requests.add(key);
    return {
      'id': int.parse(key),
      'name': key == '1' ? 'Office tree' : 'College tree',
      'version': 1,
      'nodes': [
        for (var i = 0; i < (key == '1' ? 30 : 3); i++)
          {
            'key': '$key-$i',
            'name': 'Person $key-$i',
            'relation': 'Connection',
            'parentKey': null,
            'gender': 'UNSPECIFIED',
            'contactId': i == 0 ? 42 : null
          }
      ]
    };
  }
}

void main() {
  testWidgets('all saved trees start closed around You and open independently',
      (tester) async {
    final api = SavedApi();
    Map<String, dynamic>? edited;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SavedTreeDisplay(
                    api: api,
                    cards: const [
                      {'id': 1, 'name': 'Office tree', 'count': 30},
                      {'id': 2, 'name': 'College tree', 'count': 3}
                    ],
                    busy: false,
                    onEdit: (card, key) => edited = card,
                    onDelete: (_) {})))));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(api.requests, isEmpty);
    final office = find.widgetWithText(OutlinedButton, 'Office tree');
    final college = find.widgetWithText(OutlinedButton, 'College tree');
    await tester.tap(office);
    await tester.pumpAndSettle();
    expect(find.text('Person 1-29'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Person 1-0'));
    await tester.pumpAndSettle();
    expect(find.text('Phone: +911111111111'), findsOneWidget);
    expect(find.text('Contact groups: College'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Overview'));
    await tester.pumpAndSettle();
    await tester.tap(college);
    await tester.pumpAndSettle();
    expect(api.requests, ['1', '2']);
    expect(find.text('Person 1-29'), findsOneWidget);
    expect(find.text('Person 2-0'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Overview'));
    await tester.pumpAndSettle();
    await tester.tap(office);
    await tester.pumpAndSettle();
    expect(find.text('Person 1-29'), findsNothing);
    expect(find.text('Person 2-0'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Edit tree'));
    await tester.pumpAndSettle();
    expect(edited?['id'], 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('initial node selection reveals its ancestors', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReviewedTreeCanvas(nodes: const [
      {
        'key': 'a',
        'name': 'Parent',
        'relation': 'Connection',
        'parentKey': null
      },
      {'key': 'b', 'name': 'Child', 'relation': 'Connection', 'parentKey': 'a'}
    ], selected: 'b', onSelect: (_) {}))));
    await tester.pump();
    expect(find.text('Child'), findsOneWidget);
    expect(find.byTooltip('Collapse Parent'), findsOneWidget);
  });
}
