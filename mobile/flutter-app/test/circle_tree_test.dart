import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/circle_tree_branch.dart';

class TreeApi extends MyAapthaApi {
  TreeApi():super(AuthTokenBundle(tokenType:'Bearer',accessToken:'fixture',refreshToken:'fixture',expiresIn:900));
  final List<int> cursors=[];
  @override Future<Map<String,dynamic>> addressBook({String query='',int afterId=0,int? circleId}) async {
    expect(circleId,7);cursors.add(afterId);
    return {'items':[{'id':afterId==0?11:12,'displayName':afterId==0?'Private rider one':'Private rider two','emails':[],'phones':[]}],'nextCursor':afterId==0?11:null,'total':2};
  }
}
void main(){
  testWidgets('circle branches expand members and private contacts before explicit messaging',(tester)async{
    final api=TreeApi();var messages=0;
    final circle=CircleModel(id:7,name:'Cycling',description:'',ownerName:'Owner',members:[CircleMember(person:Person(id:1,displayName:'Rider Alex',accountStatus:'ACTIVE'),admin:false,creator:false)],currentUserAdmin:true,currentUserCanPost:true,postingPermission:'ALL_MEMBERS');
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:CircleTreeBranch(api:api,circle:circle,privateCount:2,unread:0,onMessages:()=>messages++)))));
    expect(find.text('Rider Alex').hitTestable(),findsNothing);
    await tester.tap(find.text('Cycling'));await tester.pumpAndSettle();
    expect(find.text('Rider Alex').hitTestable(),findsOneWidget);expect(messages,0);expect(api.cursors,isEmpty);
    await tester.tap(find.text('Show private contacts (2)'));await tester.pumpAndSettle();
    expect(find.text('Private rider one'),findsOneWidget);
    await tester.tap(find.text('Load more contacts'));await tester.pumpAndSettle();
    expect(find.text('Private rider two'),findsOneWidget);expect(api.cursors,[0,11]);
    await tester.tap(find.text('Messages'));expect(messages,1);expect(tester.takeException(),isNull);
  });
}
