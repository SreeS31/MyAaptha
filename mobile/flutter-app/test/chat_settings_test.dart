import 'package:myaaptha_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/app_shell.dart';
class ChatApi extends MyAapthaApi {
  ChatApi():super(AuthTokenBundle(tokenType:'Bearer',accessToken:'test',refreshToken:'test',expiresIn:900));
  bool archived=false,muted=false,markedUnread=false;
  @override
  Future<List<CircleConversation>> circleConversations()async=>[CircleConversation.fromJson({'circleId':8,'displayName':'Family circle','lastMessage':'Circle update','lastMessageAt':'2026-09-30T00:00:00Z','unreadCount':2})];
  @override Future<List<DirectConversation>> directConversations() async => [DirectConversation(userId:2,displayName:'Friend',lastMessage:'Hello',lastMessageAt:DateTime(2026),unreadCount:0,archived:archived,muted:muted,markedUnread:markedUnread)];
  @override Future<bool> messagePreferences() async=>true;
  @override Future<void> saveChatSettings(int other,{bool? archived,bool? muted,bool? markedUnread}) async {this.archived=archived??this.archived;this.muted=muted??this.muted;this.markedUnread=markedUnread??this.markedUnread;}
}
void main(){
  testWidgets('chat settings archive, mute and unread filters sync through API',(tester) async {
    final api=ChatApi();
    await tester.pumpWidget(MaterialApp(theme:AppTheme.light(),home:Scaffold(body:MessagesScreen(api:api))));await tester.pumpAndSettle();
    expect(find.text('Family circle'),findsOneWidget);
    await tester.tap(find.byTooltip('Chat actions'));await tester.pumpAndSettle();
    await tester.tap(find.text('Mute'));await tester.pumpAndSettle();expect(api.muted,true);expect(find.text('Friend (Muted)'),findsOneWidget);
    await tester.tap(find.byTooltip('Chat actions'));await tester.pumpAndSettle();
    await tester.tap(find.text('Mark unread'));await tester.pumpAndSettle();expect(api.markedUnread,true);
    await tester.tap(find.widgetWithText(ChoiceChip,'Unread'));await tester.pumpAndSettle();expect(find.text('Hello'),findsOneWidget);
    await tester.tap(find.byTooltip('Chat actions'));await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));await tester.pumpAndSettle();expect(api.archived,true);expect(find.text('Hello'),findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip,'Archived'));await tester.pumpAndSettle();expect(find.text('Hello'),findsOneWidget);
    await tester.tap(find.byTooltip('Chat actions'));await tester.pumpAndSettle();
    await tester.tap(find.text('Unarchive'));await tester.pumpAndSettle();expect(api.archived,false);expect(api.muted,true);expect(api.markedUnread,true);
    await tester.tap(find.widgetWithText(ChoiceChip,'Groups & circles'));await tester.pumpAndSettle();expect(find.text('Family circle'),findsOneWidget);expect(find.text('Hello'),findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip,'People'));await tester.pumpAndSettle();expect(find.text('Family circle'),findsNothing);expect(find.text('Hello'),findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

