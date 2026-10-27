import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/app_shell.dart';

class OAuthFixtureApi extends MyAapthaApi {
  OAuthFixtureApi()
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'fixture',
            refreshToken: 'fixture',
            expiresIn: 900));
  bool availabilityFails = false, available = true;
  int starts = 0, reads = 0;
  int? terminal;
  @override
  Future<Map<String, dynamic>> addressBookProviders() async {
    if (availabilityFails) {
      throw const MyAapthaApiException('Unavailable', statusCode: 503);
    }
    return {'google': available, 'microsoft': false};
  }

  @override
  Future<Map<String, dynamic>> startContactOAuth(
      String email, String provider) async {
    starts++;
    return {
      'authorizationUrl': 'https://provider.invalid/fixture',
      'resultKey': 'fixture-key'
    };
  }

  @override
  Future<List<Map<String, dynamic>>> contactOAuthResult(String key) async {
    reads++;
    if (terminal != null) {
      throw MyAapthaApiException(
          'Contact access was cancelled or denied. Nothing was imported.',
          statusCode: terminal);
    }
    return [];
  }
}

void main() {
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(launcher, (call) async => true));
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(launcher, null));
  Future<void> open(WidgetTester tester, OAuthFixtureApi api) async {
    await tester
        .pumpWidget(MaterialApp(home: ContactOrganizerScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Google'), 200,
        scrollable: find.byType(Scrollable).first);
  }

  testWidgets(
      'unavailable providers disable connection while device analysis remains available',
      (tester) async {
    final api = OAuthFixtureApi()..available = false;
    await open(tester, api);
    final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Google'), matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
    expect(api.starts, 0);
    expect(find.textContaining('Email contact providers are not available'),
        findsOneWidget);
  });
  testWidgets(
      'provider lookup failure can be retried without reading device contacts',
      (tester) async {
    final api = OAuthFixtureApi()..availabilityFails = true;
    await open(tester, api);
    await tester.scrollUntilVisible(find.text('Retry providers'), 150,
        scrollable: find.byType(Scrollable).first);
    api.availabilityFails = false;
    await tester.tap(find.text('Retry providers'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Google'), -150,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<FilledButton>(find.ancestor(
                of: find.text('Google'), matching: find.byType(FilledButton)))
            .onPressed,
        isNotNull);
    expect(api.starts, 0);
  });
  testWidgets('provider denial stops polling and shows the terminal error',
      (tester) async {
    final api = OAuthFixtureApi()..terminal = 422;
    await open(tester, api);
    await tester.enterText(
        find.widgetWithText(TextField, 'Email containing your contacts'),
        'fixture@example.test');
    await tester.tap(find.text('Google'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(api.starts, 1);
    expect(api.reads, 1);
    expect(find.textContaining('cancelled or denied'), findsOneWidget);
  });
  testWidgets('cancelling provider wait prevents a later result read',
      (tester) async {
    final api = OAuthFixtureApi();
    await open(tester, api);
    await tester.enterText(
        find.widgetWithText(TextField, 'Email containing your contacts'),
        'fixture@example.test');
    await tester.tap(find.text('Google'));
    await tester.pump();
    await tester.tap(find.text('Cancel connection'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(api.reads, 0);
    expect(find.textContaining('connection cancelled'), findsOneWidget);
  });
  testWidgets('empty provider results end the busy state without saving',
      (tester) async {
    final api = OAuthFixtureApi();
    await open(tester, api);
    await tester.enterText(
        find.widgetWithText(TextField, 'Email containing your contacts'),
        'fixture@example.test');
    await tester.tap(find.text('Google'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(api.reads, 1);
    expect(find.textContaining('No contacts were found'), findsOneWidget);
  });
}
