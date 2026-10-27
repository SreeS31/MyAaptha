import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:myaaptha_mobile/core/contacts/device_contact_access.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/address_book_screen.dart';
import 'package:myaaptha_mobile/features/shell/presentation/app_shell.dart';

class PermissionContactApi extends MyAapthaApi {
  PermissionContactApi()
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'fixture',
            refreshToken: 'fixture',
            expiresIn: 900));
  List<Map<String, dynamic>> analyzed = [];
  int imports = 0, accepts = 0, analyses = 0;
  @override
  Future<Map<String, dynamic>> addressBook(
          {String query = '', int afterId = 0, int? circleId}) async =>
      {'items': [], 'total': 0, 'nextCursor': null};
  @override
  Future<Map<String, dynamic>> addressBookProviders() async =>
      {'google': false, 'microsoft': false};
  @override
  Future<List<Map<String, dynamic>>> addressCircles() async => [];
  @override
  Future<List<Map<String, dynamic>>> analyzeContacts(
      List<Map<String, dynamic>> contacts) async {
    analyses++;
    analyzed = contacts;
    return [];
  }

  @override
  Future<Map<String, dynamic>> acceptContactSuggestions(
      List<Map<String, dynamic>> suggestions) async {
    accepts++;
    return {};
  }

  @override
  Future<Map<String, dynamic>> importReviewedAddressBook(
      List<Map<String, dynamic>> contacts, String source, bool organize) async {
    imports++;
    return {'added': contacts.length};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissionChannel =
      MethodChannel('flutter.baseflow.com/permissions/methods');
  const contactsChannel = MethodChannel('com.github.s0nerik.fast_contacts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var status = PermissionStatus.limited.index;
  var contactCount = 1;
  final calls = <String>[];
  Completer<int>? permissionResponse;
  setUp(() {
    calls.clear();
    permissionResponse = null;
    status = PermissionStatus.limited.index;
    contactCount = 1;
    messenger.setMockMethodCallHandler(permissionChannel, (call) async {
      expect(call.method, 'requestPermissions');
      expect(call.arguments, [Permission.contacts.value]);
      calls.add('request');
      return {
        Permission.contacts.value:
            await (permissionResponse?.future ?? Future.value(status))
      };
    });
    messenger.setMockMethodCallHandler(contactsChannel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'fetchAllContacts':
          return {'count': contactCount, 'timeMillis': 0};
        case 'getAllContactsPage':
          return [
            {
              'id': 'allowed-only',
              'structuredName': {'displayName': 'Allowed Person'},
              'phones': [
                {'number': '+15551234567', 'label': 'mobile'}
              ],
              'emails': []
            }
          ];
        case 'clearFetchedContacts':
          return null;
        default:
          throw StateError('Unexpected contact operation');
      }
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(permissionChannel, null);
    messenger.setMockMethodCallHandler(contactsChannel, null);
  });

  for (final permission in [
    PermissionStatus.denied,
    PermissionStatus.restricted,
    PermissionStatus.permanentlyDenied,
    PermissionStatus.provisional
  ]) {
    test('permission $permission never reads contacts', () async {
      status = permission.index;
      await expectLater(
          readPermittedDeviceContacts(), throwsA(isA<MyAapthaApiException>()));
      expect(calls, ['request']);
    });
  }
  test('granted access reads only after permission and clears plugin cache',
      () async {
    status = PermissionStatus.granted.index;
    final contacts = await readPermittedDeviceContacts();
    expect(contacts.single.id, 'allowed-only');
    expect(calls, [
      'request',
      'fetchAllContacts',
      'getAllContactsPage',
      'clearFetchedContacts'
    ]);
  });
  testWidgets(
      'limited organizer access analyzes allowed records without saving',
      (tester) async {
    final api = PermissionContactApi();
    await tester
        .pumpWidget(MaterialApp(home: ContactOrganizerScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Allow and analyze contacts').hitTestable(), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Allow and analyze contacts'));
    await tester.pumpAndSettle();
    expect(api.analyzed.single['contact_key'], 'allowed-only');
    expect(api.analyzed.single['display_name'], 'Allowed Person');
    expect(api.accepts, 0);
    expect(api.imports, 0);
  });
  testWidgets('limited address-book access opens review before any import',
      (tester) async {
    final api = PermissionContactApi();
    await tester.pumpWidget(MaterialApp(home: AddressBookScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import all device contacts'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Review contacts'), findsOneWidget);
    expect(find.text('Allowed Person'), findsOneWidget);
    expect(api.imports, 0);
    expect(api.analyzed, isEmpty);
  });
  testWidgets('denied organizer access never reads or analyzes contacts',
      (tester) async {
    status = PermissionStatus.permanentlyDenied.index;
    final api = PermissionContactApi();
    await tester
        .pumpWidget(MaterialApp(home: ContactOrganizerScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Allow and analyze contacts').hitTestable(), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Allow and analyze contacts'));
    await tester.pumpAndSettle();
    expect(calls, ['request']);
    expect(api.analyzed, isEmpty);
    expect(api.accepts, 0);
    expect(find.textContaining('Nothing was uploaded.'), findsOneWidget);
  });
  testWidgets('leaving during the permission request never uploads contacts',
      (tester) async {
    permissionResponse = Completer<int>();
    final api = PermissionContactApi();
    await tester
        .pumpWidget(MaterialApp(home: ContactOrganizerScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Allow and analyze contacts').hitTestable(), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Allow and analyze contacts'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    permissionResponse!.complete(PermissionStatus.limited.index);
    await tester.pumpAndSettle();
    expect(calls, ['request']);
    expect(api.analyses, 0);
    expect(api.accepts, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('repeated taps while permission is pending cause one analysis',
      (tester) async {
    permissionResponse = Completer<int>();
    final api = PermissionContactApi();
    await tester
        .pumpWidget(MaterialApp(home: ContactOrganizerScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Allow and analyze contacts').hitTestable(), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Allow and analyze contacts'));
    await tester.tap(find.text('Allow and analyze contacts'));
    expect(calls, ['request']);
    permissionResponse!.complete(PermissionStatus.limited.index);
    await tester.pumpAndSettle();
    expect(api.analyses, 1);
    expect(api.accepts, 0);
  });
  testWidgets('empty permitted contacts never trigger an analysis request',
      (tester) async {
    contactCount = 0;
    final api = PermissionContactApi();
    await tester
        .pumpWidget(MaterialApp(home: ContactOrganizerScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Allow and analyze contacts').hitTestable(), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Allow and analyze contacts'));
    await tester.pumpAndSettle();
    expect(api.analyses, 0);
    expect(
        find.textContaining('No named contacts are available'), findsOneWidget);
    expect(calls, ['request', 'fetchAllContacts', 'clearFetchedContacts']);
  });
}
