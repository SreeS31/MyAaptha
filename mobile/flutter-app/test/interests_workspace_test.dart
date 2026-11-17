import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/interests_screen.dart';
import 'package:myaaptha_mobile/features/shell/presentation/interest_catalog.dart';
class InterestsApi extends MyAapthaApi {
 InterestsApi():super(AuthTokenBundle(tokenType:'Bearer',accessToken:'fixture',refreshToken:'fixture',expiresIn:900));
 List<String> selected=['Cycling'];String? membership;bool admin=false;int discussionReads=0;List<Map<String,dynamic>> discussion=[];
 Map<String,dynamic> get group=>{'id':'fixture-group','name':'Hyderabad Cycle Club','topic':'Cycling','area':'Hyderabad','description':'Weekend rides','membership':membership,'admin':admin,'memberCount':1};
 @override Future<List<String>> interests()async=>selected;
 @override Future<List<String>> saveInterests(List<String> values)async=>selected=values;
 @override Future<Map<String,dynamic>> interestGroups({String query='',String area='',String topic='',bool mine=false,int page=0})async=>{'items':area.toLowerCase()=='mumbai'?[]:[group],'hasNext':false};
 @override Future<Map<String,dynamic>> interestGroup(String id)async=>group;
 @override Future<Map<String,dynamic>> joinInterestGroup(String id)async{membership='REQUESTED';return group;}
 @override Future<void> leaveInterestGroup(String id)async{membership=null;}
 @override Future<Map<String,dynamic>> interestRequests(String id,{int page=0})async=>{'items':[],'hasNext':false};
 @override Future<Map<String,dynamic>> interestMessages(String id,{int page=0})async{discussionReads++;return {'items':discussion,'hasNext':false};}
 @override Future<void> postInterestMessage(String id,String body)async{discussion=[{'id':'message','author':'Fixture','body':body,'mine':true}];}
 @override Future<void> deleteInterestMessage(String id,String message)async{discussion=[];}
}
void main(){
 test('catalogue has broad coverage and no duplicate values',(){expect(allInterests.length,410);expect(allInterests.toSet().length,410);expect(allInterests,containsAll(['Cycling','Sport shooting','Startups']));});
 testWidgets('picker preserves large selections and adds a custom interest',(tester)async{
  final choices=List.generate(350,(i)=>'Custom $i');List<String>? saved;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:()async{saved=await showInterestPicker(context,choices);},child:const Text('Edit interests'))))));
  await tester.tap(find.text('Edit interests'));await tester.pumpAndSettle();expect(find.text('350 selected'),findsOneWidget);
  await tester.enterText(find.byType(TextField),'Bird sketching');await tester.pumpAndSettle();await tester.ensureVisible(find.text('Add "Bird sketching"'));await tester.tap(find.text('Add "Bird sketching"'));await tester.pumpAndSettle();await tester.tap(find.text('Save interests'));await tester.pumpAndSettle();expect(saved!.length,351);expect(saved,contains('Bird sketching'));
 });
 testWidgets('group approval refresh gates discussion and leaving revokes access',(tester)async{
  final api=InterestsApi();await tester.pumpWidget(MaterialApp(home:InterestGroupScreen(api:api,group:api.group)));await tester.pumpAndSettle();expect(api.discussionReads,0);
  await tester.tap(find.text('Request to join'));await tester.pumpAndSettle();expect(find.text('Your request is awaiting admin approval.'),findsOneWidget);expect(api.discussionReads,0);
  api.membership='ACTIVE';await tester.tap(find.byTooltip('Refresh group'));await tester.pumpAndSettle();expect(api.discussionReads,1);
  await tester.enterText(find.byType(TextField),'Sunday ride?');await tester.ensureVisible(find.text('Post message'));await tester.tap(find.text('Post message'));await tester.pumpAndSettle();expect(api.discussion.single['body'],'Sunday ride?');
  await tester.scrollUntilVisible(find.text('Leave group'),-200,scrollable:find.byType(Scrollable).first);await tester.tap(find.text('Leave group'));await tester.pumpAndSettle();expect(api.membership,null);expect(find.byType(TextField),findsNothing);
 });
 testWidgets('native area filter uses the shared directory contract',(tester)async{
  final api=InterestsApi();await tester.pumpWidget(MaterialApp(home:Scaffold(body:InterestsScreen(api:api))));await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.widgetWithText(TextField,'Area'),200,scrollable:find.byType(Scrollable).first);await tester.enterText(find.widgetWithText(TextField,'Area'),'Mumbai');await tester.pump(const Duration(milliseconds:400));await tester.pumpAndSettle();expect(find.text('No groups found. Try another area or create a group.'),findsOneWidget);
 });
 testWidgets('group editor preserves the selected topic at narrow width and large text',(tester)async{
  tester.view.physicalSize=const Size(320,740);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  Map<String,dynamic>? result;
  final original={'name':'Cycle Club','topic':'Cycling','area':'Hyderabad','description':'Weekend rides'};
  await tester.pumpWidget(MaterialApp(builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:const TextScaler.linear(2)),child:child!),home:Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:()async{result=await interestGroupEditor(context,group:original);},child:const Text('Edit group'))))));
  await tester.tap(find.text('Edit group'));await tester.pumpAndSettle();
  await tester.tap(find.text('Save group'));await tester.pumpAndSettle();expect(result,original);expect(tester.takeException(),isNull);
 });

}
