import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/features/shell/presentation/native_voice_note.dart';

class FakeCapture implements VoiceNoteCapture {
  bool permission = true;
  String? path;
  int stops = 0;
  bool disposed = false;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start(String path) async {
    this.path = path;
    File(path).writeAsBytesSync([1, 2, 3, 4]);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  testWidgets(
      'audio-only recording returns review bytes and removes its temporary file',
      (tester) async {
    final directory =
        Directory.systemTemp.createTempSync('myaaptha-voice-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final capture = FakeCapture();
    PlatformFile? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NativeVoiceNote(
                disabled: false,
                capture: capture,
                temporaryDirectory: () async => directory,
                onReady: (value) {
                  result = value;
                }))));
    await tester.tap(find.byTooltip('Record voice note'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Stop voice recording'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop voice recording'));
    for (int i = 0;
        i < 100 && (result == null || File(capture.path!).existsSync());
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(result?.bytes, [1, 2, 3, 4]);
    expect(File(capture.path!).existsSync(), isFalse);
    expect(capture.stops, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('discarding a voice note never attaches bytes', (tester) async {
    final directory =
        Directory.systemTemp.createTempSync('myaaptha-voice-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final capture = FakeCapture();
    int attachments = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NativeVoiceNote(
                disabled: false,
                capture: capture,
                temporaryDirectory: () async => directory,
                onReady: (_) => attachments++))));
    await tester.tap(find.byTooltip('Record voice note'));
    await tester.pumpAndSettle();
    final discard = tester.widget<IconButton>(find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Discard voice recording'));
    await tester.runAsync(() async {
      discard.onPressed!();
      final end = DateTime.now().add(const Duration(seconds: 5));
      while (File(capture.path!).existsSync() && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(attachments, 0);
    expect(File(capture.path!).existsSync(), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('microphone denial never starts a recorder', (tester) async {
    final capture = FakeCapture()..permission = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NativeVoiceNote(
                disabled: false,
                capture: capture,
                onReady: (_) => fail('Permission was denied')))));
    await tester.tap(find.byTooltip('Record voice note'));
    await tester.pumpAndSettle();
    expect(capture.path, isNull);
    expect(find.textContaining('Allow microphone access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
