import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/data/auth_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';

// Explicitly opt in: this creates synthetic accounts in an isolated preview.
const syncUrl = String.fromEnvironment('SYNC_API_URL');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'native API client reads and writes shared settings, circles and messages',
      () async {
    expect(['127.0.0.1', 'localhost'].contains(Uri.parse(syncUrl).host), true,
        reason: 'Synthetic synchronization fixtures must use a local preview.');
    final previousHttpOverride = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousHttpOverride);
    SharedPreferences.setMockInitialValues({});
    final client = ApiClient(baseUrl: syncUrl);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final password = 'Sync-$stamp';
    Future<({int id, MyAapthaApi api})> member(int index) async {
      final username = 'native-sync-$stamp-$index';
      final response = await client.post('/api/users', {
        'username': username,
        'password': password,
        'phoneNumber':
            '+1884${(stamp + index).toString().substring((stamp + index).toString().length - 10)}'
      });
      expect(response.statusCode, 200);
      final id = (response.decodeJson() as Map)['id'] as int;
      final session = await AuthApi(apiClient: client)
          .login(LoginRequest(identifier: username, password: password));
      return (id: id, api: MyAapthaApi(session, client: client));
    }

    final owner = await member(1), friend = await member(2);
    final providerAvailability = await owner.api.addressBookProviders();
    expect(providerAvailability.keys, unorderedEquals(['google', 'microsoft']));
    expect(providerAvailability.values.every((value) => value is bool), true);
    await expectLater(owner.api.contactOAuthResult('missing-native-$stamp'),
        throwsA(isA<MyAapthaApiException>().having((e) => e.statusCode, 'status', 404)));
    final relationshipCountBeforeImport = (await owner.api.relationships()).length;
    final contactImport = await owner.api.importReviewedAddressBook([
      {
        'displayName': 'Permitted fixture $stamp',
        'phones': ['+15551234567'],
        'emails': <String>[],
        'organization': '',
        'groups': <String>[],
        'selected': true,
        'circleNames': <String>[]
      }
    ], 'device', false);
    expect(contactImport['added'], 1);
    final contactPage = await owner.api.addressBook();
    expect(contactPage['total'], 1);
    final savedContact = (contactPage['items'] as List).single as Map;
    final savedContactId = savedContact['id'] as int;
    try {
      expect(savedContact['displayName'], 'Permitted fixture $stamp');
      expect(savedContact['source'], 'device');
      expect(savedContact['relationshipId'], isNull);
      expect((await friend.api.addressBook())['total'], 0);
      await expectLater(friend.api.removeAddressContact(savedContactId),
          throwsA(isA<MyAapthaApiException>().having((e) => e.statusCode, 'status', 404)));
      final secondSession = await AuthApi(apiClient: client).login(
          LoginRequest(identifier: 'native-sync-$stamp-1', password: password));
      final reloaded = await MyAapthaApi(secondSession, client: client).addressBook();
      expect((reloaded['items'] as List).single['id'], savedContactId);
      expect((await owner.api.relationships()).length, relationshipCountBeforeImport);
    } finally {
      await owner.api.removeAddressContact(savedContactId);
    }
    expect((await owner.api.addressBook())['total'], 0);
    await expectLater(
        owner.api.moderationPage(),
        throwsA(isA<MyAapthaApiException>()
            .having((e) => e.statusCode, 'status', 403)));
    final analysisPolicy = await owner.api.healthAnalysisPolicy();
    expect(analysisPolicy['configured'], false,
        reason: 'Local acceptance must not enable paid health processing.');
    expect(analysisPolicy['consentRequired'], true);
    await expectLater(
        owner.api.analyzeHealthReport(
            Uint8List.fromList(
                utf8.encode('%PDF-1.4\nSynthetic consent fixture\n%%EOF')),
            'consent-fixture.pdf',
            processingConsent: true),
        throwsA(isA<MyAapthaApiException>()
            .having((e) => e.statusCode, 'status', 503)));
    final report = <String, dynamic>{
      'reportName': 'Synthetic native report'.padRight(200, 'r'),
      'laboratory': 'Synthetic lab'.padRight(200, 'l'),
      'notes': ''.padRight(1000, 'n'),
      'collectedOn': '2026-10-01',
      'measurements': [
        {
          'metricName': 'Synthetic marker'.padRight(120, 'm'),
          'value': 10,
          'unit': ''.padRight(40, 'u')
        }
      ]
    };
    await owner.api.addHealthReport(report);
    final savedReports = (await owner.api.healthDashboard())['reports'] as List;
    expect(savedReports, hasLength(1));
    expect(savedReports.single['notes'], report['notes']);
    expect(savedReports.single['reportName'], report['reportName']);
    expect(savedReports.single['measurements'][0]['metricName'],
        (report['measurements'] as List).single['metricName']);
    expect(savedReports.single['measurements'][0]['unit'],
        (report['measurements'] as List).single['unit']);
    expect((await friend.api.healthDashboard())['reports'], isEmpty);
    for (final invalid in [
      {...report, 'collectedOn': '2099-01-01'},
      {...report, 'measurements': <Object>[]},
      {
        ...report,
        'measurements': <Object?>[null]
      }
    ]) {
      await expectLater(
          owner.api.addHealthReport(invalid),
          throwsA(isA<MyAapthaApiException>()
              .having((e) => e.statusCode, 'status', 400)));
    }
    expect((await owner.api.healthDashboard())['reports'], hasLength(1));
    await owner.api
        .deleteHealthReport((savedReports.single['id'] as num).toInt());
    expect((await owner.api.healthDashboard())['reports'], isEmpty);
    final approver = await member(3);
    await owner.api.addTrustedPerson(friend.id, 'STAR');
    await owner.api.addTrustedPerson(approver.id, 'STAR');
    await owner.api.createSocialPost(
        'Synthetic native emergency document', 'PRIVATE',
        bytes: Uint8List.fromList(
            utf8.encode('%PDF-1.4\nSynthetic native fixture\n%%EOF')),
        fileName: 'native-emergency.pdf');
    final emergency = await friend.api
        .startEmergencyAccess(owner.id, 'Synthetic local acceptance check');
    final emergencyId = (emergency['id'] as num).toInt();
    expect(emergency['canViewDocuments'], false);
    await approver.api.decideEmergencyAccess(emergencyId, true);
    expect((await friend.api.emergencyRequests()).single['canViewDocuments'],
        true);
    expect((await owner.api.emergencyRequests()).single['canViewDocuments'],
        false);
    expect((await approver.api.emergencyRequests()).single['canViewDocuments'],
        false);
    final documents = await friend.api.emergencyDocuments(emergencyId);
    expect(documents, hasLength(1));
    final documentId = documents.single['id'];
    expect(
        await friend.api.attachment(
            '/api/trust/emergencies/$emergencyId/documents/$documentId/media'),
        isNotEmpty);
    await owner.api.removeTrustedPerson(friend.id, 'STAR');
    expect((await friend.api.emergencyRequests()).single['canViewDocuments'],
        false);
    await expectLater(friend.api.emergencyDocuments(emergencyId),
        throwsA(isA<MyAapthaApiException>()));
    final security = await AuthApi(apiClient: client).securityPolicy();
    expect(security.required, isA<bool>());
    await owner.api.addFinancialTransaction({
      'source': 'MANUAL',
      'amount': 7,
      'direction': 'EXPENSE',
      'category': 'OTHER',
      'merchant': 'Before UTC midnight',
      'occurredAt': '2026-09-30T23:59:59Z'
    });
    await owner.api.addFinancialTransaction({
      'source': 'MANUAL',
      'amount': 8,
      'direction': 'EXPENSE',
      'category': 'OTHER',
      'merchant': 'At UTC midnight',
      'occurredAt': '2026-10-01T00:00:00Z'
    });
    expect((await owner.api.financialSummary('2026-09'))['spending'], 7);
    expect((await owner.api.financialSummary('2026-10'))['spending'], 8);
    final photo = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j3ioAAAAASUVORK5CYII=');
    final portrait =
        await owner.api.uploadProfilePhoto(photo, 'native-profile.png');
    expect(portrait.value('profilePhoto'), contains('/api/profile/media/'));
    final gallery = await owner.api
        .uploadProfilePhoto(photo, 'native-gallery.png', gallery: true);
    expect(gallery.data['photos'], hasLength(1));
    expect((await friend.api.profile()).value('profilePhoto'), isEmpty);
    await owner.api.removeProfilePhoto(galleryIndex: 0);
    expect((await owner.api.profile()).data['photos'], isEmpty);
    await owner.api.removeProfilePhoto();
    expect((await owner.api.profile()).value('profilePhoto'), isEmpty);
    final original = await owner.api.applicationSettings();
    final saved = await owner.api.updateApplicationSettings(
        {...original, 'compactLayout': true, 'timeZone': 'Asia/Kolkata'});
    expect(saved['compactLayout'], true);
    expect((await owner.api.applicationSettings())['timeZone'], 'Asia/Kolkata');
    final policy = await owner.api.uploadPolicy();
    expect((policy['level'] as Map)['id'], 1);
    await owner.api.addFinancialTransaction({
      'source': 'MANUAL',
      'amount': 19,
      'direction': 'EXPENSE',
      'category': 'OTHER',
      'merchant': 'Native sync purchase',
      'occurredAt': DateTime.now().toUtc().toIso8601String()
    });
    final finance = await owner.api.financialSummary(
        DateTime.now().toUtc().toIso8601String().substring(0, 7));
    expect(
        (finance['transactions'] as List)
            .any((item) => (item as Map)['merchant'] == 'Native sync purchase'),
        true);
    await owner.api.addRelationship(
        Person(id: friend.id, displayName: 'Friend', accountStatus: 'ACTIVE'),
        'Friend',
        'FRIENDS');
    final circle =
        await owner.api.createChatGroup('Native sync group', [friend.id]);
    expect(
        (await friend.api.circles()).any((item) => item.id == circle.id), true);
    await owner.api.sendDirectMessage(friend.id, 'native-sync-needle-$stamp');
    final hits = await friend.api.searchAllChats('native-sync-needle-$stamp');
    expect(
        hits.any((hit) =>
            hit['type'] == 'DIRECT' && hit['conversationId'] == owner.id),
        true);
    final event = await owner.api.saveTimelineEvent({
      'eventKey': 'custom-native-$stamp',
      'date': '2026-10-08',
      'kind': 'Employment',
      'title': 'Native milestone',
      'detail': 'Shared with web'
    });
    expect(event['title'], 'Native milestone');
    expect(
        (await owner.api.timelineEvents())
            .any((e) => e['eventKey'] == 'custom-native-$stamp'),
        true);
    expect((await friend.api.timelineEvents()).isEmpty, true);
    await owner.api
        .saveTimelineEvent({...event, 'title': 'Updated native milestone'});
    expect((await owner.api.timelineEvents()).single['title'],
        'Updated native milestone');
    await friend.api.deleteTimelineEvent('custom-native-$stamp');
    expect((await owner.api.timelineEvents()).length, 1);
    await owner.api.deleteTimelineEvent('custom-native-$stamp');
    expect(await owner.api.timelineEvents(), isEmpty);
    await owner.api.saveMessagePreferences(false);
    expect(await owner.api.messagePreferences(), false);
  }, skip: syncUrl.isEmpty, timeout: const Timeout(Duration(minutes: 2)));
}
