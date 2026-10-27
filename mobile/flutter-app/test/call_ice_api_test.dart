import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';

class IceClient extends ApiClient {
  IceClient(this.status):super(baseUrl:'http://unused');
  final int status;
  String? requested,token;
  @override Future<ApiResponse> get(String path,{String? bearerToken})async{
    requested=path;token=bearerToken;
    final body=jsonEncode(status==200?{'iceServers':[{'urls':['turn:relay.test:3478'],'username':'expiry:7','credential':'temporary'}],'relayConfigured':true,'credentialsExpireAt':1234}:{'message':'Call relay is not configured'});
    return ApiResponse(statusCode:status,body:body,bodyBytes:Uint8List.fromList(utf8.encode(body)));
  }
}
void main(){
  MyAapthaApi api(IceClient client)=>MyAapthaApi(AuthTokenBundle(tokenType:'Bearer',accessToken:'fixture',refreshToken:'fixture',expiresIn:900),client:client);
  test('uses authenticated shared relay configuration including temporary credentials',()async{
    final client=IceClient(200),result=await api(client).callIceConfiguration();
    expect(client.requested,'/api/network/calls/ice');expect(client.token,'fixture');
    expect(result['relayConfigured'],true);expect((result['iceServers'] as List).first['credential'],'temporary');
  });
  test('does not silently replace an unavailable required relay with public STUN',()async{
    await expectLater(api(IceClient(503)).callIceConfiguration(),throwsA(isA<MyAapthaApiException>().having((e)=>e.statusCode,'status',503)));
  });
}
