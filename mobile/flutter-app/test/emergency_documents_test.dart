import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/emergency_documents_screen.dart';

class EmergencyApi extends MyAapthaApi {
 EmergencyApi():super(AuthTokenBundle(tokenType:'Bearer',accessToken:'test',refreshToken:'test',expiresIn:900));
 bool denied=false;
 String? openedPath;
 @override Future<List<Map<String,dynamic>>> emergencyDocuments(int id)async{if(denied)throw const MyAapthaApiException('Emergency access is not active');return [{'id':9,'mediaName':'record.pdf','mediaType':'application/pdf','caption':'Private report','mediaUrl':'https://untrusted.example/document'}];}
 @override Future<Uint8List> attachment(String path)async{openedPath=path;if(denied)throw const MyAapthaApiException('Emergency access is not active');return Uint8List.fromList([37,80,68,70]);}
}
void main(){
 testWidgets('opens media through the authorized same-API path and drops stale metadata on denial',(tester)async{
   final api=EmergencyApi();var opens=0;
   await tester.pumpWidget(MaterialApp(home:EmergencyDocumentsScreen(api:api,requestId:4,opener:(bytes,type,name)async{opens++;expect(type,'application/pdf');expect(name,'record.pdf');return true;})));await tester.pumpAndSettle();
   await tester.tap(find.text('record.pdf'));await tester.pumpAndSettle();expect(api.openedPath,'/api/trust/emergencies/4/documents/9/media');expect(opens,1);
   api.denied=true;await tester.tap(find.text('record.pdf'));await tester.pumpAndSettle();expect(opens,1);expect(find.text('record.pdf'),findsNothing);expect(find.textContaining('not active'),findsOneWidget);
   api.denied=false;await tester.tap(find.text('Check access again'));await tester.pumpAndSettle();expect(find.text('record.pdf'),findsOneWidget);
 });
 testWidgets('initial access denial shows no document list and supports a server recheck',(tester)async{
   final api=EmergencyApi()..denied=true;await tester.pumpWidget(MaterialApp(home:EmergencyDocumentsScreen(api:api,requestId:4)));await tester.pumpAndSettle();
   expect(find.text('record.pdf'),findsNothing);expect(find.text('Check access again'),findsOneWidget);
 });
}
