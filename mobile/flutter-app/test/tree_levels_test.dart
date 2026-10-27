import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/app_shell.dart';

class LevelApi extends MyAapthaApi {
  LevelApi():super(AuthTokenBundle(tokenType:'Bearer',accessToken:'test',refreshToken:'test',expiresIn:900));
  int? requestedLevels;
  @override Future<Map<String,dynamic>> previewBroadcast(String audienceType,{int? anchorUserId,String? location,int? levels}) async {
    requestedLevels=levels;
    return {'recipients':[], 'excludedCount':0};
  }
}
void main(){
  testWidgets('selected depth reaches preview and changing depth clears old preview',(tester) async {
    final api=LevelApi();
    await tester.pumpWidget(MaterialApp(home:RelationshipBroadcastScreen(api:api,relationships:[Relationship(id:1,type:'Father',visibilityScope:'RELATIVES',person:Person(id:10,displayName:'Parent',accountStatus:'ACTIVE'))])));
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);await tester.pumpAndSettle();await tester.tap(find.text('Parent').last);await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).last);await tester.pumpAndSettle();await tester.tap(find.text('2 levels').last);await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Preview recipients'));await tester.tap(find.text('Preview recipients'));await tester.pumpAndSettle();expect(api.requestedLevels,2);expect(find.text('0 recipients'),findsOneWidget);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>).last);await tester.tap(find.byType(DropdownButtonFormField<int>).last);await tester.pumpAndSettle();await tester.tap(find.text('3 levels').last);await tester.pumpAndSettle();expect(find.text('0 recipients'),findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
