import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/features/shell/presentation/app_shell.dart';
import 'package:myaaptha_mobile/features/shell/presentation/workspace_navigation.dart';
import 'profile_overview_test.dart' show ProfileApi;

void main(){
 testWidgets('hub switches sections lazily and retains an unfinished entry',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:WorkspaceHub(title:'Messages',labels:['Personal & groups','My circles','My contacts'],pages:[TextField(decoration:InputDecoration(labelText:'Unsent message')),Text('Circle tools'),Text('Contact imports')]))));
  expect(find.text('Contact imports'),findsNothing);
  await tester.enterText(find.byType(TextField),'Keep this draft');
  await tester.tap(find.text('My contacts'));await tester.pumpAndSettle();expect(find.text('Contact imports'),findsOneWidget);
  await tester.tap(find.text('Personal & groups'));await tester.pumpAndSettle();expect(find.text('Keep this draft'),findsOneWidget);
 });
 testWidgets('comparison opens the original destination for a relocated feature',(tester)async{
  String? opened;
  await tester.pumpWidget(MaterialApp(home:MenuComparisonScreen(onOpen:(path)=>opened=path)));
  await tester.scrollUntilVisible(find.text('My contacts'),250);await tester.tap(find.text('My contacts'));expect(opened,'/contacts');
  expect(workspacePrimaryLabels.length,9);expect(workspaceMenuMoves.length,19);
 });
 testWidgets('interests editor preserves concurrent changes to career data',(tester)async{
  tester.view.physicalSize=const Size(800,2200);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final api=ProfileApi();
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:ProfileScreen(api:api,area:'Interests',onDataChanged:(){}))));await tester.pumpAndSettle();
  expect(find.text('Employment'),findsNothing);
  await tester.scrollUntilVisible(find.text('Interests').last,300,scrollable:find.byType(Scrollable).first);await tester.tap(find.widgetWithText(TextButton,'Edit'));await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField),'Reading, Gardening');api.data['employer']='Updated from another session';
  await tester.scrollUntilVisible(find.text('Save Interests'),300,scrollable:find.byType(Scrollable).first);await tester.tap(find.text('Save Interests'));await tester.pumpAndSettle();
  expect(api.data['hobbies'],'Reading, Gardening');expect(api.data['employer'],'Updated from another session');
 });
 testWidgets('returning to a scoped profile refreshes saved data while keeping an open draft',(tester)async{
  tester.view.physicalSize=const Size(800,2200);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final api=ProfileApi();
  Widget screen()=>MaterialApp(home:Scaffold(body:ProfileScreen(api:api,area:'Career',onDataChanged:(){})));
  await tester.pumpWidget(screen());await tester.pumpAndSettle();expect(find.text('Original'),findsOneWidget);
  api.data['employer']='Changed in another section';await tester.pumpWidget(screen());await tester.pumpAndSettle();expect(find.text('Changed in another section'),findsOneWidget);
  await tester.tap(find.widgetWithText(TextButton,'Edit').last);await tester.pumpAndSettle();
  final title=find.byWidgetPredicate((w)=>w is TextField&&w.decoration?.labelText=='Job title');await tester.enterText(title,'Unfinished role');
  api.data['employer']='Latest saved employer';await tester.pumpWidget(screen());await tester.pumpAndSettle();expect(find.text('Unfinished role'),findsOneWidget);
  await tester.tap(find.text('Cancel'));await tester.pumpAndSettle();expect(find.text('Latest saved employer'),findsOneWidget);expect(find.byType(TextField),findsNothing);
 });

}
