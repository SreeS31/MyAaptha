import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/reviewed_trees_screen.dart';

class TreesApi extends MyAapthaApi {
  TreesApi()
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'test',
            refreshToken: 'test',
            expiresIn: 900));
  bool dismissed = false;
  Map<String, dynamic>? saved;
  Map<String, dynamic> get tree => {
        'id': null,
        'sourceKey': 'a' * 64,
        'name': 'Acme Office',
        'reason': 'Shared organization: Acme Office',
        'confidence': 'Strong clue',
        'version': 0,
        'nodes': [
          for (int i = 0; i < 3; i++)
            {
              'key': 'c$i',
              'contactId': i + 1,
              'name': ['Alice', 'Bob', 'Charlie'][i],
              'relation': 'Colleague',
              'parentKey': null
            }
        ]
      };
  @override
  Future<Map<String, dynamic>> suggestedRelationshipTrees(
          {int offset = 0}) async =>
      {
        'scannedContacts': 2000,
        'totalSuggestions': dismissed ? 0 : 1,
        'dismissedCount': dismissed ? 1 : 0,
        'nextOffset': null,
        'items': dismissed
            ? []
            : [
                {
                  'id': null,
                  'key': 'a' * 64,
                  'name': 'Acme Office',
                  'reason': 'Shared organization',
                  'confidence': 'Strong clue',
                  'count': 3,
                  'preview': tree['nodes']
                }
              ]
      };
  @override
  Future<Map<String, dynamic>> reviewedRelationshipTree(String key,
          {bool saved = false}) async =>
      tree;
  @override
  Future<void> dismissRelationshipTree(String key) async {
    dismissed = true;
  }

  @override
  Future<void> restoreRelationshipTrees() async {
    dismissed = false;
  }

  @override
  Future<Map<String, dynamic>> saveReviewedRelationshipTree(
      Map<String, dynamic> value) async {
    saved = value;
    return {...value, 'id': 1, 'version': 1};
  }
}

void main() {
  testWidgets(
      'suggestion counts and dismiss restore work without adding people',
      (tester) async {
    final api = TreesApi();
    await tester.pumpWidget(MaterialApp(home: ReviewedTreesScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('2000 contacts reviewed'), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(api.dismissed, isTrue);
    await tester.tap(find.text('Restore dismissed'));
    await tester.pumpAndSettle();
    expect(api.dismissed, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('tree save needs review and at least three nodes',
      (tester) async {
    final api = TreesApi();
    await tester.pumpWidget(MaterialApp(home: ReviewedTreesScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review tree'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('I reviewed these connections'), 300,
        scrollable: find
            .descendant(
                of: find.byType(ReviewedTreeEditor),
                matching: find.byType(Scrollable))
            .first);
    final button = find.widgetWithText(FilledButton, 'Save reviewed tree');
    await tester.scrollUntilVisible(button, 150,
        scrollable: find
            .descendant(
                of: find.byType(ReviewedTreeEditor),
                matching: find.byType(Scrollable))
            .first);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.ensureVisible(find.text('I reviewed these connections'));
    await tester.tap(find.text('I reviewed these connections'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(api.saved?['nodes'], hasLength(3));
    expect(tester.takeException(), isNull);
  });
}
