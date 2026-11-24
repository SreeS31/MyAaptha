import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart' as audio;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

abstract interface class VoiceNoteCapture {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<void> stop();
  Future<void> dispose();
}

class AudioVoiceNoteCapture implements VoiceNoteCapture {
  final audio.AudioRecorder recorder = audio.AudioRecorder();
  @override
  Future<bool> hasPermission() => recorder.hasPermission();
  @override
  Future<void> start(String path) => recorder.start(
      const audio.RecordConfig(
          encoder: audio.AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1),
      path: path);
  @override
  Future<void> stop() async {
    await recorder.stop();
  }

  @override
  Future<void> dispose() => recorder.dispose();
}

/// Captures input audio only. The temporary recording is erased after review bytes are returned.
class NativeVoiceNote extends StatefulWidget {
  const NativeVoiceNote(
      {super.key,
      required this.onReady,
      required this.disabled,
      this.capture,
      this.temporaryDirectory});
  final VoiceNoteCapture? capture;
  final Future<Directory> Function()? temporaryDirectory;
  static Future<void> Function()? cancelActive;
  final ValueChanged<PlatformFile> onReady;
  final bool disabled;
  @override
  State<NativeVoiceNote> createState() => _NativeVoiceNoteState();
}

class _NativeVoiceNoteState extends State<NativeVoiceNote>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(cancel());
    }
  }

  Future<void> cancel() async {
    generation++;
    await starting;
    await cleanup();
    if (mounted) setState(() => busy = false);
  }

  bool recording = false, busy = false;
  int seconds = 0;
  Timer? timer;
  VoiceNoteCapture? _capture;
  VoiceNoteCapture get capture =>
      _capture ??= widget.capture ?? AudioVoiceNoteCapture();
  Future<void>? starting;
  File? file;
  int generation = 0;
  Future<void> cleanup() async {
    timer?.cancel();
    if (recording) {
      recording = false;
      try {
        await capture.stop();
      } catch (_) {}
    }
    try {
      if (await file?.exists() ?? false) await file?.delete();
    } catch (_) {}
    file = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    generation++;
    if (NativeVoiceNote.cancelActive == cancel) {
      NativeVoiceNote.cancelActive = null;
    }
    unawaited(() async {
      await starting;
      await cleanup();
      await _capture?.dispose();
    }());
    super.dispose();
  }

  Future<void> begin() {
    final task = start();
    starting = task;
    return task.whenComplete(() {
      if (identical(starting, task)) {
        starting = null;
      }
    });
  }

  Future<void> start() async {
    if (busy || recording) return;
    final token = ++generation;
    NativeVoiceNote.cancelActive = cancel;
    setState(() => busy = true);
    File? destination;
    try {
      if (!await capture.hasPermission()) {
        throw const FormatException(
            'Allow microphone access to record a voice note.');
      }
      if (!mounted || token != generation) {
        return;
      }
      final directory =
          await (widget.temporaryDirectory?.call() ?? getTemporaryDirectory());
      if (!mounted || token != generation) {
        await cleanup();
        return;
      }
      file = File(
          '${directory.path}/myaaptha-voice-${DateTime.now().microsecondsSinceEpoch}.m4a');
      destination = file;
      await capture.start(file!.path);
      if (!mounted || token != generation) {
        recording = true;
        await cleanup();
        return;
      }
      setState(() {
        recording = true;
        seconds = 0;
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (seconds >= 299) {
          finish();
        } else {
          setState(() => seconds++);
        }
      });
    } catch (e) {
      await cleanup();
      if (mounted && token == generation) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voice recording could not start: $e')));
      }
    } finally {
      if (!mounted || token != generation) {
        try {
          if (await destination?.exists() ?? false) await destination?.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> finish({bool discard = false}) async {
    if (busy) return;
    setState(() => busy = true);
    timer?.cancel();
    final token = generation;
    try {
      if (recording) {
        await capture.stop();
        recording = false;
      }
      if (!discard && file != null) {
        final bytes = await file!.readAsBytes();
        if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
          throw const FormatException(
              'Record a voice note smaller than 25 MB.');
        }
        if (mounted && token == generation) {
          widget.onReady(PlatformFile(
              name: 'voice-note-${DateTime.now().millisecondsSinceEpoch}.m4a',
              size: bytes.length,
              bytes: bytes));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      await cleanup();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => recording
      ? Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'),
          IconButton(
              tooltip: 'Stop voice recording',
              onPressed: busy ? null : () => finish(),
              icon: const Icon(Icons.stop_circle_outlined)),
          IconButton(
              tooltip: 'Discard voice recording',
              onPressed: busy ? null : () => finish(discard: true),
              icon: const Icon(Icons.close))
        ])
      : IconButton(
          tooltip: 'Record voice note',
          onPressed: widget.disabled || busy ? null : begin,
          icon: const Icon(Icons.mic_none));
}
