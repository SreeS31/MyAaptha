import 'package:myaaptha_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/chat_discovery_screen.dart';
import 'package:myaaptha_mobile/features/shell/presentation/upload_settings_screen.dart';

class SyncApi extends MyAapthaApi {
  SyncApi({this.admin = false})
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'test',
            refreshToken: 'test',
            expiresIn: 900));
  final bool admin;
  int used = 0, policyReads = 0;
  Map<String, dynamic>? saved;
  String? groupName;
  List<int>? members;
  final level = <String, dynamic>{
    'id': 1,
    'name': 'Free',
    'storageBytes': 1073741824,
    'uploadBytes': 26214400,
    'maxRetentionDays': 7,
    'allowNever': true
  };
  @override
  Future<Map<String, dynamic>> uploadPolicy() async {
    policyReads++;
    return {'level': level, 'usedBytes': used};
  }

  @override
  Future<Map<String, dynamic>> sessionProfile() async =>
      {'role': admin ? 'ADMIN' : 'USER'};
  @override
  Future<List<Map<String, dynamic>>> uploadLevels() async => [level];
  @override
  Future<void> saveUploadLevel(Map<String, dynamic> value) async {
    saved = value;
    level.addAll(value);
  }

  @override
  Future<List<ChatTarget>> forwardTargets() async =>
      [const ChatTarget(type: 'DIRECT', id: 2, name: 'Friend')];
  @override
  Future<List<Relationship>> relationships() async => [
        Relationship(
            id: 1,
            type: 'Friend',
            person:
                Person(id: 2, displayName: 'Friend', accountStatus: 'ACTIVE'),
            visibilityScope: 'FRIENDS')
      ];
  @override
  Future<List<Map<String, dynamic>>> searchAllChats(String query) async => [
        {
          'type': 'DIRECT',
          'conversationId': 2,
          'messageId': 9,
          'name': 'Friend',
          'text': 'Shared message needle'
        }
      ];
  @override
  Future<CircleModel> createChatGroup(String name, List<int> ids) async {
    groupName = name;
    members = ids;
    return CircleModel.fromJson({
      'id': 8,
      'name': name,
      'description': 'Group conversation',
      'members': [],
      'ownerName': 'Me',
      'currentUserAdmin': true,
      'currentUserCanPost': true,
      'postingPermission': 'ALL_MEMBERS'
    });
  }
}

void main() {
  testWidgets(
      'storage refresh reads current account usage and hides admin controls',
      (tester) async {
    final api = SyncApi();
    await tester.pumpWidget(MaterialApp(theme:AppTheme.light(),home: UploadSettingsScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Manage user levels'), findsNothing);
    expect(find.text('0.00 GB used'), findsOneWidget);
    api.used = 536870912;
    await tester.tap(find.byTooltip('Refresh storage'));
    await tester.pumpAndSettle();
    expect(find.text('0.50 GB used'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
  });
  testWidgets('admin level editing validates retention and sends API fields',
      (tester) async {
    tester.view.physicalSize=const Size(800,1600);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final api = SyncApi(admin: true);
    await tester.pumpWidget(MaterialApp(theme:AppTheme.light(),home: UploadSettingsScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Manage user levels'),200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage user levels'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Level 1: Free'));
    await tester.tap(find.text('Level 1: Free'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Maximum days'), '0');
    await tester.tap(find.text('Save level'));
    await tester.pumpAndSettle();
    expect(api.saved, isNull);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Maximum days'), '14');
    await tester.tap(find.text('Save level'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.saved?['maxRetentionDays'], 14);
    expect(api.saved?['storageBytes'], 1073741824);
  });
  testWidgets('message search and new groups use the shared chat API',
      (tester) async {
    final api = SyncApi();
    await tester.pumpWidget(MaterialApp(theme:AppTheme.light(),home: ChatDiscoveryScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Shared message needle'), findsOneWidget);
    await tester.tap(find.text('Create a group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Find members'), '');
    await tester.enterText(
        find.widgetWithText(TextField, 'Group name'), 'Family');
    await tester.tap(find.text('Friend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();
    expect(api.groupName, 'Family');
    expect(api.members, [2]);
  });
}

