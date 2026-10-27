import 'package:fast_contacts/fast_contacts.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../network/myaaptha_api.dart';

/// The operating system limits the returned records when access is limited.
/// Reading is separate from review, analysis and saving; this function uploads nothing.
Future<List<Contact>> readPermittedDeviceContacts(
    {bool Function()? isActive}) async {
  if (kIsWeb) {
    throw const MyAapthaApiException(
        'Use a CSV/vCard export in this browser, or open the Android/iOS app.');
  }
  final status = await Permission.contacts.request();
  if (isActive != null && !isActive()) return [];
  if (!status.isGranted && !status.isLimited) {
    throw MyAapthaApiException(status.isPermanentlyDenied
        ? 'Contact access is disabled. Enable it in device settings or choose a contact file. Nothing was uploaded.'
        : 'Contact access was not granted. Nothing was uploaded. Choose a contact file or try again.');
  }
  return FastContacts.getAllContacts();
}
