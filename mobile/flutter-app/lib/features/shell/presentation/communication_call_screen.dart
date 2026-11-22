import 'dart:async';
import 'dart:convert';
import 'native_voice_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class CommunicationCallsScreen extends StatefulWidget {
  const CommunicationCallsScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<CommunicationCallsScreen> createState() =>
      _CommunicationCallsScreenState();
}

class _CommunicationCallsScreenState extends State<CommunicationCallsScreen> {
  List<Map<String, dynamic>>? calls;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await widget.api.communicationCallHistory();
      if (mounted) {
        setState(() {
          calls = values;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Calls'), actions: [
        IconButton(
            tooltip: 'Refresh calls',
            onPressed: load,
            icon: const Icon(Icons.refresh))
      ]),
      body: error != null
          ? Center(child: Text(error!))
          : calls == null
              ? const Center(child: CircularProgressIndicator())
              : calls!.isEmpty
                  ? const Center(child: Text('No recent calls.'))
                  : ListView(children: [
                      for (final call in calls!)
                        ListTile(
                            leading: Icon(call['callType'] == 'VIDEO'
                                ? Icons.videocam_outlined
                                : Icons.call_outlined),
                            title: Text(call['name'] as String),
                            subtitle: Text(
                                '${call['ended'] == true ? 'Call again' : 'Join call'} · ${DateTime.tryParse(call['createdAt'] as String)?.toLocal().toString() ?? ''}'),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => CommunicationCallScreen(
                                          api: widget.api,
                                          incoming: call['ended'] == true
                                              ? null
                                              : call,
                                          scope: call['scope'] as String,
                                          target: ((call['scope'] == 'DIRECT' &&
                                                      call['creatorId'] !=
                                                          call['currentUserId']
                                                  ? call['creatorId']
                                                  : call['targetId']) as num)
                                              .toInt(),
                                          type: call['callType'] as String)));
                              await load();
                            })
                    ]));
}

class CommunicationCallButton extends StatelessWidget {
  const CommunicationCallButton(
      {super.key,
      required this.api,
      required this.scope,
      required this.target});
  final MyAapthaApi api;
  final String scope;
  final int target;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
      tooltip: 'Call',
      icon: const Icon(Icons.call_outlined),
      onSelected: (type) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CommunicationCallScreen(
                  api: api, scope: scope, target: target, type: type))),
      itemBuilder: (_) => const [
            PopupMenuItem(value: 'AUDIO', child: Text('Voice call')),
            PopupMenuItem(value: 'VIDEO', child: Text('Video call'))
          ]);
}

class CommunicationCallScreen extends StatefulWidget {
  const CommunicationCallScreen(
      {super.key,
      required this.api,
      this.scope = 'DIRECT',
      this.target = 0,
      this.type = 'AUDIO',
      this.incoming});
  final MyAapthaApi api;
  final String scope, type;
  final int target;
  final Map<String, dynamic>? incoming;
  static bool isOpen = false;
  @override
  State<CommunicationCallScreen> createState() =>
      _CommunicationCallScreenState();
}

class _CommunicationCallScreenState extends State<CommunicationCallScreen> {
  final localRenderer = RTCVideoRenderer();
  final peers = <int, RTCPeerConnection>{};
  final renderers = <int, RTCVideoRenderer>{};
  final pending = <int, List<RTCIceCandidate>>{};
  MediaStream? local;
  Map<String, dynamic>? room;
  Map<String, dynamic> configuration = {};
  Timer? timer;
  bool busy = false,
      muted = false,
      cameraOff = false,
      closing = false,
      speaker = false;
  int after = 0;
  String? error;
  bool get video =>
      (room?['callType'] ?? widget.incoming?['callType'] ?? widget.type) ==
      'VIDEO';
  @override
  void initState() {
    super.initState();
    CommunicationCallScreen.isOpen = true;
    initialize();
  }

  Future<void> initialize() async {
    try {
      await NativeVoiceNote.cancelActive?.call();
      if (!mounted) return;
      configuration = {
        'iceServers': (await widget.api.callIceConfiguration())['iceServers']
      };
      if (!mounted) return;
      await localRenderer.initialize();
      if (!mounted) {
        await localRenderer.dispose();
        return;
      }
      final stream = await navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': video});
      if (!mounted) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        await stream.dispose();
        return;
      }
      local = stream;
      localRenderer.srcObject = stream;
      final value = widget.incoming ??
          await widget.api.createCommunicationCall(
              widget.scope, widget.target, widget.type);
      if (!mounted) {
        await widget.api.leaveCommunicationCall(value['id'] as String);
        return;
      }
      room = value;
      if (value['callType'] == 'AUDIO') {
        for (final track in stream.getVideoTracks()) {
          await track.stop();
          await stream.removeTrack(track);
        }
      }
      speaker = video;
      try {
        await Helper.setSpeakerphoneOn(speaker);
      } catch (_) {}
      room = await widget.api.joinCommunicationCall(value['id'] as String);
      if (!mounted) return;
      setState(() {});
      await poll();
      if (mounted && !closing) {
        timer =
            Timer.periodic(const Duration(milliseconds: 1500), (_) => poll());
      }
    } catch (e) {
      releaseDevices();
      if (mounted) setState(() => error = e.toString());
      if (room != null) {
        unawaited(widget.api
            .leaveCommunicationCall(room!['id'] as String)
            .catchError((_) {}));
      }
    }
  }

  Future<RTCPeerConnection> connection(int id) async {
    final previous = peers[id];
    if (previous != null) return previous;
    final peer = await createPeerConnection(configuration);
    if (!mounted || closing) {
      await peer.close();
      throw StateError('Call closed');
    }
    peers[id] = peer;
    for (final track in local!.getTracks()) {
      await peer.addTrack(track, local!);
    }
    peer.onIceCandidate = (candidate) {
      if (mounted && !closing && candidate.candidate != null) {
        unawaited(widget.api
            .sendCommunicationSignal(
                room!['id'] as String, id, 'ice', jsonEncode(candidate.toMap()))
            .catchError((_) {}));
      }
    };
    peer.onTrack = (event) async {
      if (event.streams.isEmpty || !mounted || closing) return;
      var renderer = renderers[id];
      if (renderer == null) {
        renderer = RTCVideoRenderer();
        await renderer.initialize();
        if (!mounted || closing) {
          await renderer.dispose();
          return;
        }
        renderers[id] = renderer;
      }
      renderer.srcObject = event.streams.first;
      if (mounted) setState(() {});
    };
    peer.onConnectionState = (value) {
      if (mounted &&
          value == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        setState(
            () => error = 'A participant could not connect. Try rejoining.');
      }
    };
    return peer;
  }

  Future<void> poll() async {
    if (busy || closing || room == null) return;
    busy = true;
    try {
      final value = await widget.api.communicationCall(room!['id'] as String);
      if (!mounted || closing) return;
      if (value['ended'] == true) {
        await hangup();
        return;
      }
      room = value;
      final self = (value['currentUserId'] as num).toInt();
      final members = (value['members'] as List)
          .cast<Map>()
          .where((m) => m['status'] == 'JOINED' && m['userId'] != self)
          .toList();
      for (final id in peers.keys.toList()) {
        if (!members.any((m) => m['userId'] == id)) {
          await peers.remove(id)?.close();
          await renderers.remove(id)?.dispose();
          pending.remove(id);
        }
      }
      for (final member in members) {
        final id = (member['userId'] as num).toInt();
        if (peers.containsKey(id)) continue;
        final peer = await connection(id);
        if (self < id) {
          await peer.setLocalDescription(await peer.createOffer());
          final offer = await peer.getLocalDescription();
          await widget.api.sendCommunicationSignal(
              value['id'] as String, id, 'offer', jsonEncode(offer!.toMap()));
        }
      }
      for (final signal in await widget.api
          .communicationSignals(value['id'] as String, after)) {
        if (!mounted || closing) return;
        final sender = (signal['senderId'] as num).toInt();
        if (!members.any((m) => m['userId'] == sender)) {
          after = (signal['id'] as num).toInt();
          continue;
        }
        final peer = await connection(sender),
            payload =
                jsonDecode(signal['payload'] as String) as Map<String, dynamic>;
        if (signal['type'] == 'ice') {
          final candidate = RTCIceCandidate(
              payload['candidate'] as String?,
              payload['sdpMid'] as String?,
              (payload['sdpMLineIndex'] as num?)?.toInt());
          if (await peer.getRemoteDescription() != null) {
            await peer.addCandidate(candidate);
          } else {
            pending.putIfAbsent(sender, () => []).add(candidate);
          }
        } else {
          await peer.setRemoteDescription(RTCSessionDescription(
              payload['sdp'] as String?, payload['type'] as String?));
          for (final candidate
              in pending.remove(sender) ?? <RTCIceCandidate>[]) {
            await peer.addCandidate(candidate);
          }
          if (signal['type'] == 'offer') {
            await peer.setLocalDescription(await peer.createAnswer());
            final answer = await peer.getLocalDescription();
            await widget.api.sendCommunicationSignal(value['id'] as String,
                sender, 'answer', jsonEncode(answer!.toMap()));
          }
        }
        after = (signal['id'] as num).toInt();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (e is MyAapthaApiException &&
          [401, 403, 404, 409].contains(e.statusCode)) {
        releaseDevices();
      }
      if (mounted) setState(() => error = e.toString());
    } finally {
      busy = false;
    }
  }

  void releaseDevices() {
    timer?.cancel();
    for (final peer in peers.values) {
      peer.onTrack = null;
      peer.onIceCandidate = null;
      unawaited(peer.close());
    }
    peers.clear();
    for (final track in local?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    localRenderer.srcObject = null;
    unawaited(local?.dispose() ?? Future<void>.value());
    local = null;
    for (final renderer in renderers.values) {
      unawaited(renderer.dispose());
    }
    renderers.clear();
  }

  Future<void> hangup({bool everyone = false}) async {
    if (closing) return;
    closing = true;
    releaseDevices();
    try {
      if (room != null) {
        await widget.api
            .leaveCommunicationCall(room!['id'] as String, everyone: everyone);
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    closing = true;
    CommunicationCallScreen.isOpen = false;
    releaseDevices();
    unawaited(localRenderer.dispose());
    if (room != null) {
      unawaited(widget.api
          .leaveCommunicationCall(room!['id'] as String)
          .catchError((_) {}));
    }
    super.dispose();
  }

  String memberName(int id) =>
      ((room?['members'] as List?) ?? [])
          .cast<Map>()
          .where((m) => m['userId'] == id)
          .firstOrNull?['name']
          ?.toString() ??
      'Member';
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) releaseDevices();
      },
      child: Scaffold(
          backgroundColor: const Color(0xFF142E35),
          appBar: AppBar(
              title: Text(room?['name']?.toString() ?? 'Preparing call'),
              automaticallyImplyLeading: false),
          body: Column(children: [
            if (error != null)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(error!,
                      style: const TextStyle(color: Colors.orangeAccent))),
            if (room != null)
              Text(
                  '${(room!['members'] as List).where((m) => m['status'] == 'JOINED').length}/${room!['capacity']} participants',
                  style: const TextStyle(color: Colors.white)),
            Expanded(
                child: GridView.count(
                    crossAxisCount:
                        MediaQuery.sizeOf(context).width > 600 ? 2 : 1,
                    padding: const EdgeInsets.all(16),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                  if (local != null)
                    Stack(children: [
                      if (video)
                        RTCVideoView(localRenderer, mirror: true)
                      else
                        const Center(
                            child: Icon(Icons.person,
                                size: 80, color: Colors.white)),
                      const Align(
                          alignment: Alignment.bottomLeft,
                          child: Text('You',
                              style: TextStyle(color: Colors.white)))
                    ]),
                  for (final item in renderers.entries)
                    Stack(children: [
                      if (video)
                        RTCVideoView(item.value)
                      else
                        const Center(
                            child: Icon(Icons.person,
                                size: 80, color: Colors.white)),
                      Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(memberName(item.key),
                              style: const TextStyle(color: Colors.white)))
                    ]),
                ])),
            if (room != null && renderers.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Waiting for others to joinâ€¦',
                      style: TextStyle(color: Colors.white))),
            SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (local != null)
                            FilledButton.tonal(
                                onPressed: () {
                                  for (final track in local!.getAudioTracks()) {
                                    track.enabled = muted;
                                  }
                                  setState(() => muted = !muted);
                                },
                                child: Text(muted ? 'Unmute' : 'Mute')),
                          if (local != null &&
                              video &&
                              local!.getVideoTracks().isNotEmpty)
                            FilledButton.tonal(
                                onPressed: () {
                                  for (final track in local!.getVideoTracks()) {
                                    track.enabled = cameraOff;
                                  }
                                  setState(() => cameraOff = !cameraOff);
                                },
                                child: Text(
                                    cameraOff ? 'Camera on' : 'Camera off')),
                          if (local != null)
                            FilledButton.tonal(
                                onPressed: () async {
                                  try {
                                    await Helper.setSpeakerphoneOn(!speaker);
                                    if (mounted) {
                                      setState(() => speaker = !speaker);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() => error = e.toString());
                                    }
                                  }
                                },
                                child: Text(
                                    speaker ? 'Speaker off' : 'Speaker on')),
                          if (local?.getVideoTracks().isNotEmpty == true)
                            FilledButton.tonal(
                                onPressed: () async {
                                  try {
                                    await Helper.switchCamera(
                                        local!.getVideoTracks().first);
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() => error = e.toString());
                                    }
                                  }
                                },
                                child: const Text('Switch camera')),
                          FilledButton(
                              onPressed: () => hangup(),
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text('Leave call')),
                          if (room != null &&
                              room!['creatorId'] == room!['currentUserId'] &&
                              room!['scope'] == 'CIRCLE')
                            TextButton(
                                onPressed: () => hangup(everyone: true),
                                child: const Text('End for everyone')),
                        ]))),
          ])));
}
