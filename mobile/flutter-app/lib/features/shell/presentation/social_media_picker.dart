import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<PlatformFile?> pickSocialMedia(FileType type) async {
  final picked = await FilePicker.platform
      .pickFiles(type: type, withData: false, withReadStream: true);
  final file = picked?.files.single;
  if (file == null) return null;
  if(file.size==0)throw StateError('Choose a non-empty media file.');
  const limit = 25 * 1024 * 1024;
  if (file.size > limit) {
    throw StateError('Choose a file no larger than 25 MB.');
  }
  if (file.bytes != null) {
    if (file.bytes!.length > limit) {
      throw StateError('Choose a file no larger than 25 MB.');
    }
    return file;
  }
  final stream = file.readStream;
  if (stream == null) {
    throw StateError('This file could not be read. Choose it again.');
  }
  final builder = BytesBuilder();
  await for (final chunk in stream) {
    if (builder.length + chunk.length > limit) {
      throw StateError('Choose a file no larger than 25 MB.');
    }
    builder.add(chunk);
  }
  final bytes = builder.takeBytes();
  if(bytes.isEmpty)throw StateError('Choose a non-empty media file.');
  return PlatformFile(name: file.name, size: bytes.length, bytes: bytes);
}
