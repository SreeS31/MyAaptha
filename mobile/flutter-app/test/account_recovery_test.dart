import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/features/auth/data/auth_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/auth/presentation/account_recovery_screen.dart';
import 'package:myaaptha_mobile/features/auth/presentation/auth_screen.dart';
import 'member_login_test.dart' show MemorySessions;

class VerificationAuth extends AuthApi {
  bool failPolicy=false,failRecovery=false;
  RegisterUserRequest? registration;
  List<String>? recovered;
  @override Future<AuthHealth> checkHealth()async=>AuthHealth(status:'ready');
  @override Future<PhoneVerificationPolicy> securityPolicy()async{
    if(failPolicy)throw const AuthApiException('Policy unavailable');
    return PhoneVerificationPolicy(required:true,configured:true,verificationUri:Uri.parse('https://app.example.invalid/verify-phone'));
  }
  @override Future<RegisterUserResult> registerUser(RegisterUserRequest request)async{
    registration=request;return RegisterUserResult(id:1,username:request.username,phoneNumber:request.phoneNumber);
  }
  @override Future<void> resetPassword(String phone,String code,String password)async{
    if(failRecovery)throw const AuthApiException('Verification code is invalid or expired');
    recovered=[phone,code,password];
  }
}
void main(){
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('policy and password reset use the shared anonymous API; verification code is sent during registration',()async{
    final calls=<http.Request>[];
    final api=AuthApi(apiClient:ApiClient(baseUrl:'http://10.0.2.2:8080',httpClient:MockClient((r)async{calls.add(r);if(r.url.path.endsWith('security-policy'))return http.Response(jsonEncode({'phoneVerificationRequired':true,'phoneVerificationConfigured':true,'phoneVerificationUrl':'http://localhost:3000/verify-phone'}),200);return http.Response('',204);}))); 
    final policy=await api.securityPolicy();expect(policy.required,true);expect(policy.verificationUri.toString(),'http://10.0.2.2:3000/verify-phone');
    await api.resetPassword('+15551234567','123456','NewSecret123');expect(calls.last.url.path,'/api/auth/reset-password');expect(jsonDecode(calls.last.body)['verificationCode'],'123456');expect(calls.last.headers.containsKey('Authorization'),false);
    expect(RegisterUserRequest(username:'asha',phoneNumber:'+15551234567',password:'Secret123',verificationCode:'123456').toJson()['verificationCode'],'123456');
  });
  test('unsafe verification addresses fail closed',()async{
    for(final url in ['javascript:alert(1)','http://untrusted.example/verify-phone','https://user:secret@app.example/verify-phone','https://app.example/other']){
      final api=AuthApi(apiClient:ApiClient(baseUrl:'http://localhost:8080',httpClient:MockClient((_)async=>http.Response(jsonEncode({'phoneVerificationRequired':true,'phoneVerificationConfigured':true,'phoneVerificationUrl':url}),200))));
      await expectLater(api.securityPolicy(),throwsA(isA<AuthApiException>()));
    }
  });
  testWidgets('registration requires the SMS code and passes it to the API',(tester)async{
    tester.view.physicalSize=const Size(800,1600);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final api=VerificationAuth();await tester.pumpWidget(MaterialApp(home:AuthScreen(onAuthenticated:(_){},authApi:api,sessionStore:MemorySessions())));await tester.pumpAndSettle();
    await tester.tap(find.text('Sign Up'));await tester.pumpAndSettle();expect(find.text('Request SMS code'),findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField,'Username'),'asha');await tester.enterText(find.widgetWithText(TextFormField,'Mobile number'),'+15551234567');await tester.enterText(find.widgetWithText(TextFormField,'Password'),'NewSecret123');
    await tester.tap(find.widgetWithText(FilledButton,'Create Account'));await tester.pumpAndSettle();expect(api.registration,isNull);expect(find.text('Enter the SMS code'),findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField,'SMS verification code'),'123456');await tester.tap(find.widgetWithText(FilledButton,'Create Account'));await tester.pumpAndSettle();expect(api.registration?.verificationCode,'123456');
  });
  testWidgets('policy failure blocks registration until a successful retry',(tester)async{
    final api=VerificationAuth()..failPolicy=true;await tester.pumpWidget(MaterialApp(home:AuthScreen(onAuthenticated:(_){},authApi:api,sessionStore:MemorySessions())));await tester.pumpAndSettle();await tester.tap(find.text('Sign Up'));await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Create Account')).onPressed,isNull);
    api.failPolicy=false;await tester.ensureVisible(find.text('Retry security policy'));await tester.tap(find.text('Retry security policy'));await tester.pumpAndSettle();expect(find.text('Request SMS code'),findsOneWidget);
  });
  testWidgets('recovery validates inputs, keeps failures visible and clears sensitive fields after success',(tester)async{
    tester.view.physicalSize=const Size(800,1400);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final api=VerificationAuth()..failRecovery=true;await tester.pumpWidget(MaterialApp(home:AccountRecoveryScreen(api:api)));await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField,'Registered mobile number'),'+15551234567');await tester.enterText(find.widgetWithText(TextFormField,'SMS verification code'),'123456');await tester.enterText(find.widgetWithText(TextFormField,'New password'),'NewSecret123');
    await tester.tap(find.text('Set new password'));await tester.pumpAndSettle();expect(find.textContaining('invalid or expired'),findsOneWidget);
    api.failRecovery=false;await tester.tap(find.text('Set new password'));await tester.pumpAndSettle();expect(api.recovered,['+15551234567','123456','NewSecret123']);expect(find.textContaining('If this is an eligible account'),findsOneWidget);
    expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField,'New password')).controller!.text,isEmpty);
  });
}
