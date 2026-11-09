import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class UnavailableHelpApi extends FakeHelpApi {
  @override Future<Map<String,dynamic>> helpStatus() async => throw Exception('Offline fixture');
}

void main() {
  testWidgets('public contact remains copyable when help is unavailable', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = call.arguments['text'] as String;
      return null;
    });
    addTearDown(()=>tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,null));
    await tester.pumpWidget(MaterialApp(home:HelpChatScreen(api:UnavailableHelpApi())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Copy email address'));
    await tester.tap(find.text('Copy email address'));
    await tester.pumpAndSettle();
    expect(copied,'Help@myaaptha.com');
    expect(find.text('Email address copied.'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
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
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SwitchListTile));
    expect(find.byType(SwitchListTile).hitTestable(), findsOneWidget);
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
