import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/advisors_screen.dart';
class AdvisorsApi extends MyAapthaApi {
 AdvisorsApi():super(AuthTokenBundle(tokenType:'Bearer',accessToken:'test',refreshToken:'test',expiresIn:900));
 final people=<Map<String,dynamic>>[]; Map<String,dynamic>? captured;
 @override Future<List<Map<String,dynamic>>> advisorCategories()async=>[{'key':'PERSONAL','name':'Personal','people':people.length,'custom':false},{'key':'SPORTS','name':'Sports','people':0,'custom':false}];
 @override Future<Map<String,dynamic>> advisors(String category,{int afterId=0})async=>{'items':people,'nextCursor':null};
 @override Future<List<Map<String,dynamic>>> searchAdvisorMembers(String query)async=>[{'id':2,'name':'Coach Maya'}];
 @override Future<Map<String,dynamic>> saveAdvisor(Map<String,dynamic> value,{int? id})async{captured=value;final person={...value,'id':id??1,'kind':value['memberId']!=null?'MEMBER':'EXTERNAL','name':value['memberId']!=null?'Coach Maya':value['name'],'version':1};people.add(person);return person;}
}
void main(){
 testWidgets('private advisors support multiple categories and member post following',(tester)async{
  final api=AdvisorsApi();await tester.pumpWidget(MaterialApp(home:Scaffold(body:AdvisorsScreen(api:api,postsBuilder:(category)=>Text('Advisor feed $category')))));await tester.pumpAndSettle();await tester.tap(find.text('Add a person'));await tester.pumpAndSettle();await tester.enterText(find.byType(TextField).first,'Maya');await tester.pump(const Duration(milliseconds:300));await tester.pumpAndSettle();await tester.tap(find.text('Coach Maya'));await tester.pumpAndSettle();await tester.tap(find.widgetWithText(CheckboxListTile,'Sports'));await tester.pumpAndSettle();await tester.tap(find.text('Save advisor'));await tester.pumpAndSettle();expect(api.captured!['categories'],containsAll(['PERSONAL','SPORTS']));expect(api.captured!['followPosts'],isTrue);expect(find.text('Coach Maya'),findsOneWidget);await tester.tap(find.text('Posts'));await tester.pumpAndSettle();expect(find.text('Advisor feed ALL'),findsOneWidget);expect(tester.takeException(),isNull);
 });
 testWidgets('external reference cards do not claim external feed access',(tester)async{
  final api=AdvisorsApi();await tester.pumpWidget(MaterialApp(home:Scaffold(body:AdvisorsScreen(api:api,postsBuilder:(_)=>const SizedBox()))));await tester.pumpAndSettle();await tester.tap(find.text('Add a person'));await tester.pumpAndSettle();await tester.tap(find.text('Profile card'));await tester.pumpAndSettle();expect(find.text('Reference link only; external posts are not imported.'),findsOneWidget);await tester.enterText(find.byType(TextField).first,'Art guide');await tester.tap(find.text('Save advisor'));await tester.pumpAndSettle();expect(api.captured!['followPosts'],isFalse);expect(find.text('Art guide'),findsOneWidget);expect(tester.takeException(),isNull);
 });
}
