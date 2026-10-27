import 'package:myaaptha_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/app_shell.dart';

class ProfileApi extends MyAapthaApi {
 ProfileApi():super(AuthTokenBundle(tokenType:'Bearer',accessToken:'test',refreshToken:'test',expiresIn:900));
 Map<String,dynamic> data={'firstName':'Asha','surname':'Rao','highestQualification':'M.Tech','employer':'Original','photos':<String>[]};
 @override Future<UserProfileModel> profile() async=>UserProfileModel(Map.from(data));
 @override Future<UserProfileModel> saveProfile(Map<String,dynamic> value) async {data=Map.from(value);return UserProfileModel(data);}
}
void main(){
 testWidgets('profile is read-only until Edit; cancel discards and save preserves other sections',(tester) async {
  tester.view.physicalSize=const Size(800,2200);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final api=ProfileApi();
  await tester.pumpWidget(MaterialApp(theme:AppTheme.light(),home:Scaffold(body:ProfileScreen(api:api,onDataChanged:(){}))));await tester.pumpAndSettle();
  expect(find.byType(TextField),findsNothing);
  await tester.scrollUntilVisible(find.text('Personal details'),300,scrollable:find.byType(Scrollable).first);await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton,'Edit').first);await tester.pumpAndSettle();
  final firstName=find.byWidgetPredicate((w)=>w is TextField && w.decoration?.labelText=='First name');
  await tester.enterText(firstName,'Discard');
  await tester.scrollUntilVisible(find.text('Cancel'),300,scrollable:find.byType(Scrollable).first);await tester.tap(find.text('Cancel'));await tester.pumpAndSettle();
  expect(api.data['firstName'],'Asha');expect(find.byType(TextField),findsNothing);
  await tester.scrollUntilVisible(find.text('Personal details'),-300,scrollable:find.byType(Scrollable).first);await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton,'Edit').first);await tester.pumpAndSettle();
  await tester.enterText(firstName,'New name');api.data['employer']='Updated elsewhere';
  await tester.scrollUntilVisible(find.text('Save Personal details'),300,scrollable:find.byType(Scrollable).first);await tester.tap(find.text('Save Personal details'));await tester.pumpAndSettle();
  expect(api.data['firstName'],'New name');expect(api.data['employer'],'Updated elsewhere');expect(find.byType(TextField),findsNothing);
 });
}
