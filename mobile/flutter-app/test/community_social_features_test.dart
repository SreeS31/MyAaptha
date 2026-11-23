import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/community_activities_screen.dart';
import 'package:myaaptha_mobile/features/shell/presentation/social_tools_screen.dart';
import 'package:myaaptha_mobile/features/shell/presentation/reels_screen.dart';

class FeatureApi extends MyAapthaApi {
  FeatureApi()
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'test',
            refreshToken: 'test',
            expiresIn: 900));
  List<int> votes = [];
  bool close = false;
  Map<String, dynamic> get poll => {
        'id': 1,
        'kind': 'POLL',
        'title': 'Weekend ride',
        'details': '',
        'location': '',
        'multiple': false,
        'closed': false,
        'canManage': true,
        'options': [
          {
            'id': 1,
            'label': 'Morning',
            'count': votes.contains(1) ? 1 : 0,
            'selected': votes.contains(1)
          },
          {
            'id': 2,
            'label': 'Evening',
            'count': votes.contains(2) ? 1 : 0,
            'selected': votes.contains(2)
          }
        ],
        'responses': <String, int>{}
      };
  @override
  Future<Map<String, dynamic>> circleActivities(int id, {int? before}) async =>
      {
        'items': [poll],
        'hasNext': false
      };
  @override
  Future<Map<String, dynamic>> voteCircleActivity(
      int circle, int id, List<int> options) async {
    votes = options;
    return poll;
  }

  @override
  Future<List<Map<String, dynamic>>> socialToolList(String name) async =>
      name == 'close-friends' && close
          ? [
              {'id': 2, 'name': 'Alex'}
            ]
          : [];
  @override
  Future<List<Relationship>> relationships() async => [
        Relationship(
            id: 1,
            type: 'Friend',
            visibilityScope: 'FRIENDS',
            person: Person(
                id: 2,
                displayName: 'Alex',
                accountStatus: 'ACTIVE',
                identityType: 'ACCOUNT'))
      ];
  @override
  Future<void> setCloseFriend(int member, bool chosen) async {
    close = chosen;
  }

  @override
  Future<Map<String, dynamic>> socialBrowse(String mode, {int? before}) async =>
      {'items': <Object>[], 'hasNext': false};
}

void main() {
  testWidgets('circle polls use server votes and allow withdrawal',
      (tester) async {
    final api = FeatureApi();
    await tester.pumpWidget(
        MaterialApp(home: CommunityActivitiesScreen(api: api, circle: 9)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    expect(api.votes, [1]);
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();
    expect(api.votes, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Close Friends adds and removes the selected connected person',
      (tester) async {
    final api = FeatureApi();
    await tester.pumpWidget(MaterialApp(home: SocialToolsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Close Friends'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(api.close, true);
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(api.close, false);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty video feed remains navigable without opening a decoder',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: ReelsScreen(api: FeatureApi())));
    await tester.pumpAndSettle();
    expect(find.text('Reels'), findsOneWidget);
    expect(find.byTooltip('Share a video'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
