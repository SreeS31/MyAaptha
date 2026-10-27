import '../network/myaaptha_api.dart';

class ContactOAuthCancelled implements Exception {
  const ContactOAuthCancelled();
}

/// Only a not-yet-ready result is retried. Authorization, server and transport
/// failures must be shown instead of being hidden behind the polling timeout.
Future<T> waitForContactOAuth<T>(Future<T> Function() read,
    {required bool Function() isActive,
    int attempts = 150,
    Future<void> Function(Duration)? pause}) async {
  if (attempts < 1) throw ArgumentError.value(attempts, 'attempts');
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (!isActive()) throw const ContactOAuthCancelled();
    await (pause ?? Future<void>.delayed)(const Duration(seconds: 2));
    if (!isActive()) throw const ContactOAuthCancelled();
    try {
      final result = await read();
      if (!isActive()) throw const ContactOAuthCancelled();
      return result;
    } on MyAapthaApiException catch (error) {
      if (error.statusCode != 404) rethrow;
    }
  }
  throw const MyAapthaApiException(
      'Contact authorization timed out. Please try again. Nothing was saved.');
}
