import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/features/auth/data/auth_api.dart';
import 'package:myaaptha_mobile/features/auth/data/session_store.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/auth/presentation/auth_screen.dart';

class MemberAuth extends AuthApi {
  @override Future<PhoneVerificationPolicy> securityPolicy() async=>const PhoneVerificationPolicy(required:false,configured:false);
  LoginRequest? submitted;
  @override Future<AuthHealth> checkHealth() async => AuthHealth(status: 'ready');
  @override Future<AuthTokenBundle> login(LoginRequest request) async {
    submitted = request;
    return AuthTokenBundle(tokenType: 'Bearer', accessToken: 'member', refreshToken: 'refresh', expiresIn: 900);
  }
  @override Future<DashboardSummary> fetchDashboardSummary(String token) async => throw StateError('Members cannot read administrator statistics');
}

class MemorySessions extends SessionStore {
  AuthTokenBundle? saved;
  @override Future<AuthTokenBundle?> load() async => saved;
  @override Future<void> save(AuthTokenBundle value) async { saved = value; }
}

void main() {
  testWidgets('member sign-in opens the app without administrator statistics', (tester) async {
    final auth = MemberAuth(); final store = MemorySessions();
    AuthTokenBundle? authenticated;
    await tester.pumpWidget(MaterialApp(home: AuthScreen(authApi: auth, sessionStore: store,
        onAuthenticated: (session) => authenticated = session)));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email or mobile number'), 'member');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'StrongPassword123');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(authenticated?.accessToken, 'member');
    expect(store.saved, same(authenticated));
  });

  test('administrator code is included only when supplied', () {
    expect(LoginRequest(identifier: 'admin', password: 'secret', otpCode: '123456').toJson()['otpCode'], '123456');
    expect(LoginRequest(identifier: 'member', password: 'secret').toJson().containsKey('otpCode'), isFalse);
  });
}
