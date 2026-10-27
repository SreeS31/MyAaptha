import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/profile_media_card.dart';

AuthTokenBundle session()=>AuthTokenBundle(tokenType:'Bearer',accessToken:'test-token',refreshToken:'refresh',expiresIn:900);
class PhotoApi extends MyAapthaApi {
  PhotoApi():super(session());
  var writes=0;
  bool? gallery;
  int? removedIndex;
  @override Future<UserProfileModel> uploadProfilePhoto(Uint8List bytes,String name,{bool gallery=false}) async {writes++;this.gallery=gallery;return UserProfileModel({'firstName':'Asha','photos':<String>[]});}
  @override Future<UserProfileModel> removeProfilePhoto({int? galleryIndex}) async {writes++;removedIndex=galleryIndex;return UserProfileModel({'photos':<String>[]});}
}
void main(){
  test('photo API uses authenticated multipart and owner routes; 5 MB/type guards stop invalid uploads',() async {
    final requests=<http.Request>[];
    final api=MyAapthaApi(session(),client:ApiClient(baseUrl:'http://10.0.2.2:8080',httpClient:MockClient((request)async{requests.add(request);return http.Response(jsonEncode({'profilePhoto':'http://localhost:8080/api/profile/media/photo.png','photos':[]}),200);}))); 
    final bytes=Uint8List.fromList([137,80,78,71,13,10,26,10]);
    await api.uploadProfilePhoto(bytes,'profile.png');await api.uploadProfilePhoto(bytes,'gallery.png',gallery:true);
    await api.removeProfilePhoto();await api.removeProfilePhoto(galleryIndex:2);
    expect(requests.map((r)=>r.url.path),['/api/profile/me/photo','/api/profile/me/photos','/api/profile/me/photo','/api/profile/me/photos/2']);
    expect(requests.map((r)=>r.method),['POST','POST','DELETE','DELETE']);
    expect(requests.every((r)=>r.headers['Authorization']=='Bearer test-token'),true);
    expect(latin1.decode(requests.first.bodyBytes),contains('filename="profile.png"'));
    expect(api.profilePhotoUrl('http://localhost:8080/api/profile/media/photo.png'),'http://10.0.2.2:8080/api/profile/media/photo.png');
    await expectLater(api.uploadProfilePhoto(Uint8List(5*1024*1024+1),'large.png'),throwsFormatException);
    await expectLater(api.uploadProfilePhoto(bytes,'animated.gif'),throwsFormatException);
    await expectLater(api.uploadProfilePhoto(Uint8List(0),'empty.png'),throwsFormatException);
    expect(requests,hasLength(4));
  });
  testWidgets('upload, gallery selection, cancel and confirmed removal call the shared photo API',(tester) async {
    final api=PhotoApi();final busy=<bool>[];UserProfileModel? changed;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:ProfileMediaCard(api:api,profile:UserProfileModel({'profilePhoto':'','photos':<String>[]}),onBusy:busy.add,onChanged:(p)=>changed=p,selectPhoto:()async=>PlatformFile(name:'photo.png',size:8,bytes:Uint8List.fromList([137,80,78,71,13,10,26,10]))))));
    await tester.tap(find.text('Upload photo'));await tester.pumpAndSettle();expect(api.writes,1);expect(api.gallery,false);expect(changed?.value('firstName'),'Asha');expect(busy,[true,false]);
    await tester.tap(find.text('Add gallery photo'));await tester.pumpAndSettle();expect(api.gallery,true);expect(api.writes,2);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:ProfileMediaCard(api:api,profile:UserProfileModel({'photos':['http://invalid.test/photo.png']}),onBusy:(_){},onChanged:(_){},selectPhoto:()async=>null))));await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove gallery photo 1'));await tester.pumpAndSettle();await tester.tap(find.text('Cancel'));await tester.pumpAndSettle();expect(api.writes,2);
    await tester.tap(find.byTooltip('Remove gallery photo 1'));await tester.pumpAndSettle();await tester.tap(find.widgetWithText(FilledButton,'Remove photo'));await tester.pumpAndSettle();expect(api.removedIndex,0);expect(api.writes,3);
  });
  testWidgets('cancelled picker and read/type errors preserve existing data',(tester) async {
    final api=PhotoApi();PlatformFile? file;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:ProfileMediaCard(api:api,profile:UserProfileModel({'photos':<String>[]}),onBusy:(_){},onChanged:(_){},selectPhoto:()async=>file))));
    await tester.tap(find.text('Upload photo'));await tester.pumpAndSettle();expect(api.writes,0);
    file=PlatformFile(name:'photo.png',size:20);await tester.tap(find.text('Upload photo'));await tester.pumpAndSettle();expect(find.textContaining('could not be read'),findsOneWidget);expect(api.writes,0);
    file=PlatformFile(name:'photo.gif',size:8,bytes:Uint8List(8));await tester.tap(find.text('Upload photo'));await tester.pumpAndSettle();expect(find.textContaining('JPG, PNG or WebP'),findsOneWidget);expect(api.writes,0);
  });
}
