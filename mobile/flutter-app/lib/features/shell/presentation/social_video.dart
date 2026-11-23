import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:myaaptha_mobile/core/config/app_config.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/data/session_refresher.dart';

class SocialVideo extends StatefulWidget {
  const SocialVideo(
      {super.key,
      required this.api,
      required this.path,
      this.active = true,
      this.autoplay = false});
  final MyAapthaApi api;
  final String path;
  final bool active, autoplay;
  @override
  State<SocialVideo> createState() => _SocialVideoState();
}

class _SocialVideoState extends State<SocialVideo> with WidgetsBindingObserver {
  VideoPlayerController? player;
  int generation = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) start();
  }

  @override
  void didUpdateWidget(covariant SocialVideo old) {
    super.didUpdateWidget(old);
    if (widget.path != old.path || widget.active != old.active) {
      stop();
      if (widget.active) start();
    }
  }

  Future<void> start() async {
    final current = ++generation;
    try {
      if (!RegExp(r'^/api/social/(posts|stories)/[0-9]+/media$')
          .hasMatch(widget.path)) {
        throw StateError('Video unavailable');
      }
      final token =
          await SessionRefresher.shared.accessToken(widget.api.session);
      if (!mounted || generation != current) return;
      final next = VideoPlayerController.networkUrl(
          Uri.parse(AppConfig.apiBaseUrl).resolve(widget.path),
          httpHeaders: {'Authorization': 'Bearer $token'});
      player = next;
      await next.initialize();
      if (!mounted || generation != current) return;
      await next.setLooping(true);
      await next.setVolume(0);
      if (widget.autoplay &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await next.play();
      }
      if (mounted && generation == current) setState(() => error = null);
    } catch (_) {
      if (mounted && generation == current) {
        setState(() => error = 'Video could not play. Try again.');
      }
    }
  }

  void stop() {
    generation++;
    final old = player;
    player = null;
    if (old != null) unawaited(old.dispose());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      player?.pause();
    } else if (widget.active && widget.autoplay) {
      player?.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error!),
        TextButton(
            onPressed: () {
              stop();
              start();
            },
            child: const Text('Retry'))
      ]);
    }
    final current = player;
    if (current == null || !current.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: current,
        builder: (context, value, _) =>
            Column(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  child: AspectRatio(
                      aspectRatio: value.aspectRatio,
                      child: VideoPlayer(current))),
              VideoProgressIndicator(current, allowScrubbing: true),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                    tooltip: value.isPlaying ? 'Pause video' : 'Play video',
                    onPressed: () =>
                        value.isPlaying ? current.pause() : current.play(),
                    icon:
                        Icon(value.isPlaying ? Icons.pause : Icons.play_arrow)),
                IconButton(
                    tooltip: value.volume == 0 ? 'Unmute video' : 'Mute video',
                    onPressed: () =>
                        current.setVolume(value.volume == 0 ? 1 : 0),
                    icon: Icon(
                        value.volume == 0 ? Icons.volume_off : Icons.volume_up))
              ])
            ]));
  }
}
