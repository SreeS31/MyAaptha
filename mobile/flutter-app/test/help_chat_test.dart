import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/help_chat_screen.dart';

class FakeHelpApi extends MyAapthaApi {
  FakeHelpApi() : super(AuthTokenBundle(tokenType:'Bearer',accessToken:'test',refreshToken:'test',expiresIn:900));
  @override Future<void> clearHelpHistory() async {}
  bool enhanced=false;
  String? retried;
  @override Future<Map<String,dynamic>> retryHelp(String id) async {
    retried=id;
    return {'answer':'A more detailed answer.','mode':'AI','tier':'ENHANCED','exchangeId':'strong','notice':'','sources':[]};
  }
  bool? sentAi;
  List<Map<String,String>>? sentHistory;
  @override Future<Map<String,dynamic>> helpStatus() async => {'aiConfigured':true,'enhancedEnabled':enhanced,'questions':['Is MyAaptha free?']};
  @override Future<Map<String,dynamic>> askHelp(String message,List<Map<String,String>> history,bool useAi) async {
    sentAi=useAi;sentHistory=history;
    return {'answer':'MyAaptha is free for all users.','mode':'CACHE','tier':'BASE','exchangeId':'base','notice':'Application help','sources':[{'id':'pricing','title':'Pricing','path':'/help','content':'MyAaptha is free for all users.'}]};
  }
}

void main() {
  testWidgets('help requires opt-in for OpenAI, answers questions and clears chat', (tester) async {
    final api=FakeHelpApi();
    await tester.pumpWidget(MaterialApp(home:HelpChatScreen(api:api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Is MyAaptha free?'));
    await tester.tap(find.widgetWithText(FilledButton,'Ask'));
    await tester.pumpAndSettle();
    expect(find.text('Not satisfied? Try stronger model'),findsNothing);
    expect(api.sentAi,false);
    expect(api.sentHistory,isEmpty);
    expect(find.text('MyAaptha is free for all users.'),findsOneWidget);
    expect(find.text('Source: Pricing'),findsOneWidget);
    await tester.tap(find.byTooltip('Clear chat'));
    await tester.pumpAndSettle();
    expect(find.text('MyAaptha is free for all users.'),findsNothing);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.enterText(find.byType(TextField),'Is this free?');
    await tester.tap(find.widgetWithText(FilledButton,'Ask'));
    await tester.pumpAndSettle();
    expect(api.sentAi,true);
  });
  testWidgets('stronger retry is explicit and appears only when admin enables it', (tester) async {
    final api=FakeHelpApi()..enhanced=true;
    await tester.pumpWidget(MaterialApp(home:HelpChatScreen(api:api)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'Is MyAaptha free?');
    await tester.tap(find.widgetWithText(FilledButton,'Ask'));
    await tester.pumpAndSettle();
    expect(api.retried,isNull);
    final retry=find.text('Not satisfied? Try stronger model');
    await tester.ensureVisible(retry);await tester.tap(retry);await tester.pumpAndSettle();
    expect(api.retried,'base');
    expect(find.text('A more detailed answer.'),findsOneWidget);
  });

}
