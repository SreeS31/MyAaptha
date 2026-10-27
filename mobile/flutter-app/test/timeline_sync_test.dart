import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/core/widgets/info_help.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/timeline_screen.dart';

class TimelineApi extends MyAapthaApi {
 TimelineApi():super(AuthTokenBundle(tokenType:'Bearer',accessToken:'test',refreshToken:'test',expiresIn:900));
 final saved=<Map<String,dynamic>>[];
 @override Future<UserProfileModel> profile() async=>UserProfileModel({'dateOfBirth':'1981-11-09','graduationYear':'2011','highestQualification':'M.Tech'});
 @override Future<List<Map<String,dynamic>>> timelineRelationships() async=>[];
 @override Future<List<Map<String,dynamic>>> timelineEvents() async=>saved;
 @override Future<void> deleteTimelineEvent(String key) async {saved.removeWhere((e)=>e['eventKey']==key);}
 @override Future<Map<String,dynamic>> saveTimelineEvent(Map<String,dynamic> event) async {saved.removeWhere((e)=>e['eventKey']==event['eventKey']);saved.add(Map.from(event));return event;}
}
void main(){
 testWidgets('help hides explanatory copy until opened',(tester) async {
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:InfoHelp(title:'Storage',message:'Usage and limits follow your account.'))));
  expect(find.text('Usage and limits follow your account.'),findsNothing);
  await tester.tap(find.byTooltip('About storage'));await tester.pumpAndSettle();
  expect(find.text('Usage and limits follow your account.'),findsOneWidget);
  await tester.tap(find.text('Done'));await tester.pumpAndSettle();
  expect(find.text('Usage and limits follow your account.'),findsNothing);
 });
 testWidgets('native timeline derives milestones and persists Add and Edit through the shared API',(tester) async {
  tester.view.physicalSize=const Size(800,1400);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final api=TimelineApi();
  await tester.pumpWidget(MaterialApp(home:TimelineScreen(api:api)));await tester.pumpAndSettle();
  expect(find.text('M.Tech'),findsOneWidget);expect(find.text('Born'),findsOneWidget);
  await tester.tap(find.text('Add event'));await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField,'Title'),'New milestone');
  await tester.tap(find.text('Save event'));await tester.pumpAndSettle();
  expect(api.saved.single['title'],'New milestone');expect(find.text('New milestone'),findsOneWidget);
  await tester.tap(find.text('Edit event').first);await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField,'Title'),'Updated milestone');
  await tester.tap(find.text('Save event'));await tester.pumpAndSettle();
  expect(api.saved.single['title'],'Updated milestone');expect(find.text('Updated milestone'),findsOneWidget);
  await tester.tap(find.text('Compact'));await tester.pumpAndSettle();
  expect(find.text('Updated milestone'),findsOneWidget);
  await tester.tap(find.text('Delete event').first);await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton,'Cancel'));await tester.pumpAndSettle();
  expect(api.saved,hasLength(1));
  await tester.tap(find.text('Delete event').first);await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton,'Delete event'));await tester.pumpAndSettle();
  expect(api.saved,isEmpty);expect(find.text('Updated milestone'),findsNothing);
  await tester.tap(find.text('Edit event').first);await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField,'Title'),'Customized education');
  await tester.tap(find.text('Save event'));await tester.pumpAndSettle();
  expect(find.text('Customized education'),findsOneWidget);
  await tester.tap(find.text('Reset to source').first);await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton,'Reset to source'));await tester.pumpAndSettle();
  expect(api.saved,isEmpty);expect(find.text('M.Tech'),findsOneWidget);
 });
}
