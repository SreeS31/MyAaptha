import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/app_shell.dart';
import 'profile_overview_test.dart' show ProfileApi;

class DashboardApi extends ProfileApi {
  @override
  Future<List<Relationship>> relationships() async => [];
  @override
  Future<List<CircleModel>> circles() async => [];
  @override
  Future<List<DirectConversation>> directConversations() async => [];
  @override
  Future<Map<int, int>> circleUnreadCounts() async => {};
  @override
  Future<int> unreadNotificationCount() async => 0;
}

void main() {
  testWidgets('dashboard zero counts remain actionable and open managed profiles',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MobileDashboard(api: DashboardApi()))));
    await tester.pumpAndSettle();
    for (final label in [
      'Relationships', 'Circles', 'Managed profiles',
      'Unread messages', 'Notifications'
    ]) {
      final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, label));
      expect(tile.onTap, isNotNull);
      expect((tile.trailing as Text).data, '0');
    }
    await tester.tap(find.widgetWithText(ListTile, 'Managed profiles'));
    await tester.pumpAndSettle();
    expect(find.text('No managed profiles yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
