import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/app_shell.dart';

ConversationMessage message(int id,{bool starred=false,bool pinned=false})=>ConversationMessage.fromJson({'id':id,'senderName':'Friend','message':'Message $id','createdAt':'2026-09-25T00:00:00Z','currentUserAuthor':false,'starred':starred,'pinned':pinned});

void main(){
  testWidgets('direct chat exposes star, private pin, saved filters and visible read acknowledgement',(tester)async{
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    bool starred=false,pinned=false;final acknowledged=<int>[];String? filter;
    await tester.pumpWidget(MaterialApp(theme:AppTheme.light(),home:ConversationScreen(title:'Friend',subtitle:'Private conversation',
      load:()async=>[message(1,starred:starred,pinned:pinned)],
      loadSaved:(kind,before)async{filter=kind;return [message(1,starred:starred,pinned:pinned)];},
      setMessageFlags:(id,star,pin)async{starred=star??starred;pinned=pin??pinned;},
      acknowledgeRead:(ids)async=>acknowledged.addAll(ids),
      send:(text,parent)async{},sendAttachment:(text,bytes,name,parent,progress)async{},
      fetchAttachment:(_)async=>throw UnimplementedError(),
      editMessage:(id,text)async{},allowReplies:true)));
    await tester.pumpAndSettle();
    expect(acknowledged,[1]);
    await tester.tap(find.byTooltip('Message actions'));await tester.pumpAndSettle();
    await tester.tap(find.text('Star'));await tester.pumpAndSettle();expect(starred,true);
    await tester.tap(find.byTooltip('Message actions'));await tester.pumpAndSettle();
    await tester.tap(find.text('Pin for me'));await tester.pumpAndSettle();expect(pinned,true);
    await tester.tap(find.text('All'));await tester.pumpAndSettle();
    await tester.tap(find.text('Starred').last);await tester.pumpAndSettle();expect(filter,'starred');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('forward requires recipient selection and explicit send',(tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize=const Size(393,852);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    int? target;int? messageId;
    await tester.pumpWidget(MaterialApp(theme:AppTheme.light(),home:ConversationScreen(title:'Friend',subtitle:'Private conversation',
      load:()async=>[message(1)],
      forwardTargets:()async=>[const ChatTarget(type:'DIRECT',id:22,name:'Another friend')],
      forwardMessage:(id,to)async{messageId=id;target=to.single.id;},
      send:(text,parent)async{},sendAttachment:(text,bytes,name,parent,progress)async{},
      fetchAttachment:(_)async=>throw UnimplementedError(),editMessage:(id,text)async{})));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Message actions'));await tester.pumpAndSettle();
    await tester.tap(find.text('Forward'));await tester.pumpAndSettle();expect(target,isNull);
    await tester.tap(find.text('Another friend'));await tester.pumpAndSettle();expect(target,isNull);
    await tester.tap(find.text('Send forward'));await tester.pumpAndSettle();expect(target,22);expect(messageId,1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('forward picker limits mixed people and circles to ten',(tester)async{
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.view.physicalSize=const Size(900,1200);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    List<ChatTarget>? sent;
    await tester.pumpWidget(MaterialApp(theme:AppTheme.light(),home:ConversationScreen(title:'Friend',subtitle:'Conversation',
      load:()async=>[message(1)],forwardTargets:()async=>[const ChatTarget(type:'DIRECT',id:1,name:'Person one'),...List.generate(10,(i)=>ChatTarget(type:'CIRCLE',id:i+1,name:'Circle ${i+1}'))],
      forwardMessage:(id,targets)async{sent=targets;},send:(text,parent)async{},sendAttachment:(text,bytes,name,parent,progress)async{},fetchAttachment:(_)async=>throw UnimplementedError())));
    await tester.pumpAndSettle();await tester.tap(find.byTooltip('Message actions'));await tester.pumpAndSettle();await tester.tap(find.text('Forward'));await tester.pumpAndSettle();
    final search=find.widgetWithText(TextField,'Find people or circles');
    for(final name in ['Person one',...List.generate(9,(i)=>'Circle ${i+1}')]){
      await tester.enterText(search,name);await tester.pumpAndSettle();await tester.tap(find.text(name).last);await tester.pumpAndSettle();
    }
    expect(find.text('10 / 10 selected'),findsOneWidget);
    await tester.enterText(search,'Circle 10');await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,isNull);
    await tester.tap(find.text('Send forward'));await tester.pumpAndSettle();expect(sent!.length,10);expect(sent!.first.type,'DIRECT');expect(sent!.last.type,'CIRCLE');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('offscreen messages are not marked read',(tester)async{
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final read=<int>[];
    await tester.pumpWidget(MaterialApp(theme:AppTheme.light(),home:ConversationScreen(title:'Friend',subtitle:'Private conversation',
      load:()async=>List.generate(60,(i)=>message(i+1)),acknowledgeRead:(ids)async=>read.addAll(ids),
      send:(text,parent)async{},sendAttachment:(text,bytes,name,parent,progress)async{},fetchAttachment:(_)async=>throw UnimplementedError())));
    await tester.pumpAndSettle();expect(read,contains(60));expect(read, isNot(contains(1)));
    await tester.pumpWidget(const SizedBox());
  });
}
