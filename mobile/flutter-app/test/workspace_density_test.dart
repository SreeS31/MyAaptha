import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/core/theme/app_theme.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/app_shell.dart';

class DensityApi extends MyAapthaApi {
  DensityApi() : super(AuthTokenBundle(tokenType: 'Bearer', accessToken: 'fixture', refreshToken: 'fixture', expiresIn: 900));
  @override Future<List<Map<String, dynamic>>> socialFeed() async => [];
  @override Future<List<Map<String, dynamic>>> socialStories() async => [];
  @override Future<List<CircleModel>> circles() async => [];
}

void main() {
  testWidgets('diary opens on demand and keeps drafts when collapsed', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: Scaffold(body: SocialFeedScreen(api: DensityApi()))));
    await tester.pumpAndSettle();
    expect(find.byType(TextField).hitTestable(), findsNothing);
    await tester.tap(find.text('New diary entry'));
    await tester.pumpAndSettle();
    final entry = find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'What would you like to remember today?');
    await tester.enterText(entry, 'Keep my private draft');
    await tester.tap(find.text('New diary entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New diary entry'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(entry).controller!.text, 'Keep my private draft');
    expect(find.text('Save privately'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section navigation shares a compact row and remains scrollable', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: WorkspaceHub(
      title: 'Dashboard', labels: ['Overview', 'Timeline', 'Profile', 'Trust center'],
      pages: [Text('Overview content'), Text('Timeline content'), Text('Profile content'), Text('Trust content')],
    ))));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Overview content')).dy, lessThan(90));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Timeline'));
    await tester.pumpAndSettle();
    expect(find.text('Timeline content').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
