import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Captures input audio only. The temporary recording is erased after review bytes are returned.
class NativeVoiceNote extends StatefulWidget {
  const NativeVoiceNote(
      {super.key, required this.onReady, required this.disabled});
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
    await cleanup();
    if (mounted) setState(() => busy = false);
  }

  bool recording = false, busy = false;
  int seconds = 0;
  Timer? timer;
  MediaRecorder? recorder;
  MediaStream? stream;
  File? file;
  int generation = 0;
  Future<void> cleanup() async {
    timer?.cancel();
    if (recording) {
      recording = false;
      try {
        await recorder?.stop();
      } catch (_) {}
    }
    for (final track in stream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    await stream?.dispose();
    stream = null;
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
    unawaited(cleanup());
    super.dispose();
  }

  Future<void> begin() async {
    if (busy || recording) return;
    final token = ++generation;
    NativeVoiceNote.cancelActive = cancel;
    setState(() => busy = true);
    File? destination;
    try {
      final media = await navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': false});
      if (!mounted || token != generation) {
        for (final track in media.getTracks()) {
          track.stop();
        }
        await media.dispose();
        return;
      }
      stream = media;
      final directory = await getTemporaryDirectory();
      if (!mounted || token != generation) {
        await cleanup();
        return;
      }
      file = File(
          '${directory.path}/myaaptha-voice-${DateTime.now().microsecondsSinceEpoch}.m4a');
      destination = file;
      recorder = MediaRecorder();
      await recorder!
          .start(file!.path, audioChannel: RecorderAudioChannel.INPUT);
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
      if (mounted) {
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
    try {
      if (recording) {
        await recorder?.stop();
        recording = false;
      }
      if (!discard && file != null) {
        final bytes = await file!.readAsBytes();
        if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
          throw const FormatException(
              'Record a voice note smaller than 25 MB.');
        }
        if (mounted) {
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
