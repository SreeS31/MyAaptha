import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 test('native Interests uses the shared authenticated API paths verbs and pagination',()async{
  final requests=<http.Request>[];
  final api=MyAapthaApi(AuthTokenBundle(tokenType:'Bearer',accessToken:'fixture-token',refreshToken:'fixture',expiresIn:900),client:ApiClient(baseUrl:'https://api.test',httpClient:MockClient((r)async{
   requests.add(r);final path=r.url.path;
   if(path=='/api/interests/me')return http.Response(jsonEncode(r.method=='PUT'?jsonDecode(r.body)['interests']:['Cycling']),200,headers:{'content-type':'application/json'});
   if(r.method=='DELETE'||path.endsWith('/messages')&&r.method=='POST'||path.contains('/requests/')&&r.method=='PUT')return http.Response('',200);
   return http.Response(jsonEncode({'items':[],'hasNext':false,'id':'club'}),200,headers:{'content-type':'application/json'});
  })));
  expect(await api.interests(),['Cycling']);final values=List.generate(350,(i)=>'Hobby $i');expect((await api.saveInterests(values)).length,350);
  await api.interestGroups(query:'cycling & nature',area:'Hyderabad',topic:'Cycling',mine:true,page:2);
  final directory=requests.last;expect(directory.url.queryParameters,{'q':'cycling & nature','area':'Hyderabad','topic':'Cycling','mine':'true','page':'2'});
  final details={'name':'Hyderabad Cycle Club','topic':'Cycling','area':'Hyderabad','description':'Weekend rides'};await api.createInterestGroup(details);expect(requests.last.method,'POST');expect(requests.last.url.path,'/api/interests/groups');expect(jsonDecode(requests.last.body),details);await api.editInterestGroup('club',details);expect(requests.last.method,'PUT');expect(requests.last.url.path,'/api/interests/groups/club');
  await api.joinInterestGroup('club');expect(requests.last.method,'POST');expect(requests.last.url.path,'/api/interests/groups/club/join');
  await api.decideInterestRequest('club',7,true);expect(requests.last.method,'PUT');expect(jsonDecode(requests.last.body),{'approve':true});
  await api.interestMessages('club',page:3);expect(requests.last.url.queryParameters['page'],'3');
  await api.postInterestMessage('club','Sunday ride?');expect(jsonDecode(requests.last.body),{'body':'Sunday ride?'});
  await api.leaveInterestGroup('club');expect(requests.last.method,'DELETE');expect(requests.last.url.path,'/api/interests/groups/club/membership');
  expect(requests.every((r)=>r.headers['Authorization']=='Bearer fixture-token'),true);
 });
 test('pending membership denial remains an error rather than a public discussion fallback',()async{
  final api=MyAapthaApi(AuthTokenBundle(tokenType:'Bearer',accessToken:'fixture',refreshToken:'fixture',expiresIn:900),client:ApiClient(baseUrl:'https://api.test',httpClient:MockClient((r)async=>http.Response('{"message":"Approval required"}',403,headers:{'content-type':'application/json'}))));
  await expectLater(api.interestMessages('club'),throwsA(isA<MyAapthaApiException>().having((e)=>e.statusCode,'status',403)));
 });
}
