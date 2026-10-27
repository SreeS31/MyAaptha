import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/data/auth_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';

const syncUrl = String.fromEnvironment('SYNC_API_URL');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'native renewal clients share live PostgreSQL dates and private scanned receipts',
      () async {
    expect(['localhost', '127.0.0.1'].contains(Uri.parse(syncUrl).host), true);
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previous);
    SharedPreferences.setMockInitialValues({});
    final client = ApiClient(baseUrl: syncUrl),
        stamp = DateTime.now().microsecondsSinceEpoch,
        password = 'Renewal-$stamp';
    Future<MyAapthaApi> member(int index) async {
      final name = 'native-renewal-$stamp-$index';
      final response = await client.post('/api/users', {
        'username': name,
        'password': password,
        'phoneNumber':
            '+1885${(stamp + index).toString().substring((stamp + index).toString().length - 10)}'
      });
      expect(response.statusCode, 200);
      final auth = await AuthApi(apiClient: client)
          .login(LoginRequest(identifier: name, password: password));
      return MyAapthaApi(auth, client: client);
    }

    final owner = await member(1), other = await member(2);
    final secondAuth = await AuthApi(apiClient: client).login(LoginRequest(
        identifier: 'native-renewal-$stamp-1', password: password));
    final second = MyAapthaApi(secondAuth, client: client);
    final future = DateTime.now()
        .toUtc()
        .add(const Duration(days: 60))
        .toIso8601String()
        .substring(0, 10);
    final saved = await owner.saveRenewal({
      'kind': 'SERVICE',
      'title': 'Synthetic maintenance plan',
      'expiresOn': future,
      'timezone': 'Asia/Kolkata',
      'remindersEnabled': true,
      'archived': false
    });
    final id = saved['id'] as int;
    try {
      expect((await second.renewals()).single['expiresOn'], future);
      expect((await other.renewals()), isEmpty);
      final bytes =
          Uint8List.fromList('%PDF-1.7\n1 0 obj\n<<>>\nendobj'.codeUnits);
      await owner.attachRenewalReceipt(id, bytes, 'native-invoice.pdf');
      var shared = (await second.renewals()).single;
      expect(shared['attachmentName'], 'native-invoice.pdf');
      expect(await second.attachment(shared['attachmentUrl'] as String), bytes);
      await expectLater(other.attachment(shared['attachmentUrl'] as String),
          throwsA(isA<MyAapthaApiException>()));
      await expectLater(
          other.deleteRenewal(id),
          throwsA(isA<MyAapthaApiException>()
              .having((e) => e.statusCode, 'status', 404)));
      await second.saveRenewal({...shared, 'remindersEnabled': false}, id: id);
      shared = (await owner.renewals()).single;
      expect(shared['remindersEnabled'], false);
      expect(shared['nextReminderAt'], isNull);
      final renewed = DateTime.now()
          .toUtc()
          .add(const Duration(days: 365))
          .toIso8601String()
          .substring(0, 10);
      await owner.saveRenewal(
          {...shared, 'expiresOn': renewed, 'remindersEnabled': true},
          id: id);
      shared = (await second.renewals()).single;
      expect(shared['expiresOn'], renewed);
      expect(shared['nextReminderAt'], isNotNull);
      expect(shared['reminderDays'], [30, 15, 7, 3, 1]);
      await second.setRenewalState(id, archived: true);
      expect((await owner.renewals()).single['expiresOn'], renewed);
      await second.setRenewalState(id, archived: false);
      expect((await owner.renewals()).single['expiresOn'], renewed);
      // Exercise the real minute scheduler safely: external channels are disabled
      // on this synthetic account before creating an immediately due milestone.
      final preferences = await owner.notificationPreferences();
      await owner.updateNotificationPreferences({
        ...preferences,
        'emailEnabled': false,
        'smsEnabled': false,
        'pushEnabled': false
      });
      final utc = DateTime.now().toUtc(),
          offset = DateTime.now().toUtc().hour < 9 ? 14 : 0;
      final tomorrow = utc
          .add(Duration(hours: offset, days: 1))
          .toIso8601String()
          .substring(0, 10);
      await owner.saveRenewal({
        ...shared,
        'expiresOn': tomorrow,
        'timezone': offset == 14 ? 'Pacific/Kiritimati' : 'UTC',
        'remindersEnabled': true
      }, id: id);
      final deadline = DateTime.now().add(const Duration(seconds: 85));
      List<Map<String, dynamic>> reminders = [];
      while (DateTime.now().isBefore(deadline)) {
        reminders = (await owner.notifications())
            .where((n) => n['type'] == 'FINANCE_RENEWAL' && n['entityId'] == id)
            .toList();
        if (reminders.isNotEmpty) break;
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      expect(reminders, hasLength(1));
      expect(reminders.single['body'], contains('in 1 day'));
      expect(reminders.single['deliveries'], isEmpty);
      await second.removeRenewalReceipt(id);
      expect((await owner.renewals()).single['attachmentUrl'], isNull);
    } finally {
      await owner.deleteRenewal(id);
    }
    expect(await second.renewals(), isEmpty);
  }, skip: syncUrl.isEmpty, timeout: const Timeout(Duration(minutes: 3)));
}
