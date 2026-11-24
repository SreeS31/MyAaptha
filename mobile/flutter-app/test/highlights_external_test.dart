import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/people_highlights.dart';
import 'package:myaaptha_mobile/features/shell/presentation/external_feeds_screen.dart';

class FeaturesApi extends MyAapthaApi {
  FeaturesApi()
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'test',
            refreshToken: 'test',
            expiresIn: 900));
  bool enabled = true, starred = false, hidden = false, connected = false;
  String? feedUrl;
  Map<String, dynamic> item = {
    'id': 8,
    'sourceId': 5,
    'sourceName': 'Coach feed',
    'title': 'Practice together',
    'summary': 'A short public preview',
    'url': 'https://example.org/lesson',
    'publishedAt': null,
    'saved': false,
    'liked': false
  };
  @override
  Future<Map<String, dynamic>> peopleHighlights(
          {String view = 'frequent', int afterId = 0}) async =>
      {
        'enabled': enabled,
        'days': 90,
        'items': (view == 'frequent'
                ? enabled && !hidden
                : view == 'starred'
                    ? starred
                    : hidden)
            ? [
                {
                  'key': 'm:2',
                  'memberId': 2,
                  'contactId': null,
                  'name': 'Coach Maya',
                  'connectedCalls': 4,
                  'lastCall': null,
                  'starred': starred,
                  'hidden': hidden
                }
              ]
            : [],
        'nextCursor': null
      };
  @override
  Future<void> chooseHighlight(
      {int? memberId,
      int? contactId,
      required bool starred,
      bool hidden = false}) async {
    this.starred = starred;
    this.hidden = hidden;
  }

  @override
  Future<void> highlightPreferences(bool enabled) async {
    this.enabled = enabled;
  }

  @override
  Future<Map<String, dynamic>> advisors(String category,
          {int afterId = 0}) async =>
      {
        'items': [
          {'id': 3, 'name': 'Coach Maya'}
        ],
        'nextCursor': null
      };
  @override
  Future<Map<String, dynamic>> externalSources({int afterId = 0}) async => {
        'items': connected
            ? [
                {
                  'id': 5,
                  'advisorId': 3,
                  'title': 'Coach feed',
                  'url': 'https://example.org/feed',
                  'lastSuccess': null,
                  'error': null
                }
              ]
            : [],
        'nextCursor': null
      };
  @override
  Future<Map<String, dynamic>> externalItems(
          {String category = 'ALL', bool saved = false, int? beforeId}) async =>
      {
        'items': connected && (!saved || item['saved'] == true) ? [item] : [],
        'nextCursor': null
      };
  @override
  Future<Map<String, dynamic>> connectExternalFeed(
      int advisorId, String url) async {
    connected = true;
    feedUrl = url;
    return {'id': 5};
  }

  @override
  Future<Map<String, dynamic>> externalFlags(int id,
      {required bool saved, required bool liked}) async {
    item = {...item, 'saved': saved, 'liked': liked};
    return item;
  }
}

void main() {
  testWidgets(
      'frequent callers can be starred, hidden, restored and disabled privately',
      (tester) async {
    final api = FeaturesApi();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(child: PeopleHighlights(api: api)))));
    await tester.pumpAndSettle();
    expect(find.text('4 answered calls in 90 days'), findsOneWidget);
    await tester.tap(find.text('Star'));
    await tester.pumpAndSettle();
    expect(api.starred, isTrue);
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(find.text('Coach Maya'), findsNothing);
    await tester.tap(find.text('Hidden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(api.hidden, isFalse);
    await tester.tap(find.text('Frequent'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(api.enabled, isFalse);
    await tester.tap(find.text('Starred'));
    await tester.pumpAndSettle();
    expect(find.text('Coach Maya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('public feed connection normalizes YouTube and keeps local saves',
      (tester) async {
    final api = FeaturesApi();
    await tester.pumpWidget(MaterialApp(home: ExternalFeedsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect a public feed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach Maya').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'UCabcdefghijklmnopqrstuv');
    await tester.tap(find.text('Connect feed'));
    await tester.pumpAndSettle();
    expect(api.feedUrl,
        'https://www.youtube.com/feeds/videos.xml?channel_id=UCabcdefghijklmnopqrstuv');
    expect(find.text('Practice together'), findsOneWidget);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.item['saved'], isTrue);
    expect(find.text('Unsave'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
