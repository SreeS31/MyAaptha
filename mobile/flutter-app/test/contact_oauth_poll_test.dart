import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/contacts/contact_oauth_poll.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

void main() {
  test(
      'only pending 404 responses are retried before a successful empty result',
      () async {
    var reads = 0;
    final result = await waitForContactOAuth(() async {
      if (++reads < 3) {
        throw const MyAapthaApiException('Pending', statusCode: 404);
      }
      return <Object>[];
    }, isActive: () => true, pause: (_) async {});
    expect(result, isEmpty);
    expect(reads, 3);
  });
  for (final status in [401, 403, 422, 429, 503]) {
    test('terminal HTTP $status is reported after one read', () async {
      var reads = 0;
      await expectLater(
          waitForContactOAuth(() async {
            reads++;
            throw MyAapthaApiException('Terminal error', statusCode: status);
          }, isActive: () => true, pause: (_) async {}),
          throwsA(isA<MyAapthaApiException>()
              .having((e) => e.statusCode, 'status', status)));
      expect(reads, 1);
    });
  }
  test('transport errors are not converted to a timeout', () async {
    var reads = 0;
    await expectLater(
        waitForContactOAuth(() async {
          reads++;
          throw StateError('offline');
        }, isActive: () => true, pause: (_) async {}),
        throwsStateError);
    expect(reads, 1);
  });
  test('cancelling during the delay prevents a result request', () async {
    var active = true, reads = 0;
    await expectLater(
        waitForContactOAuth(
            () async {
              reads++;
              return 1;
            },
            isActive: () => active,
            pause: (_) async {
              active = false;
            }),
        throwsA(isA<ContactOAuthCancelled>()));
    expect(reads, 0);
  });
  test('cancelling an in-flight response discards its contents', () async {
    var active = true;
    await expectLater(
        waitForContactOAuth(() async {
          active = false;
          return ['late'];
        }, isActive: () => active, pause: (_) async {}),
        throwsA(isA<ContactOAuthCancelled>()));
  });
  test('pending responses stop at the configured retry budget', () async {
    var reads = 0;
    await expectLater(
        waitForContactOAuth(() async {
          reads++;
          throw const MyAapthaApiException('Pending', statusCode: 404);
        }, attempts: 2, isActive: () => true, pause: (_) async {}),
        throwsA(isA<MyAapthaApiException>()
            .having((e) => e.message, 'message', contains('timed out'))));
    expect(reads, 2);
  });
}
