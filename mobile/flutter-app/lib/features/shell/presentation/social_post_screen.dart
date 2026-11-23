import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/core/platform/attachment_opener.dart';
import 'social_video.dart';

Future<void> shareSocialTarget(
    BuildContext context, MyAapthaApi api, int post) async {
  final targets = await api.forwardTargets();
  if (!context.mounted) return;
  final target = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('Share post'), children: [
            for (var i = 0; i < targets.length; i++)
              SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, i),
                  child: Text(
                      '${targets[i].name} (${targets[i].type == 'CIRCLE' ? 'Circle' : 'Person'})')),
            if (targets.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Add a connection or circle first.'))
          ]));
  if (target == null) return;
  final selected = targets[target];
  await api.shareSocialPost(post, selected.type, selected.id, '');
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Post shared.')));
  }
}

class SocialPostScreen extends StatefulWidget {
  const SocialPostScreen({super.key, required this.api, required this.postId});
  final MyAapthaApi api;
  final int postId;
  @override
  State<SocialPostScreen> createState() => _SocialPostScreenState();
}

class _SocialPostScreenState extends State<SocialPostScreen> {
  Map<String, dynamic>? post;
  final comment = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final next = await widget.api.socialPost(widget.postId);
      if (mounted) {
        setState(() {
          post = next;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> act(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = post,
        path = p?['mediaUrl'] as String?,
        type = '${p?['mediaType'] ?? ''}';
    return Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: p == null
            ? Center(
                child: error == null
                    ? const CircularProgressIndicator()
                    : Text(error!))
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text('${p['authorName']}',
                    style: Theme.of(context).textTheme.titleLarge),
                if (error != null)
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (path != null && type.startsWith('image/'))
                  FutureBuilder<Uint8List>(
                      future: widget.api.socialMedia(path),
                      builder: (context, snap) => snap.hasData
                          ? Image.memory(snap.data!)
                          : const LinearProgressIndicator()),
                if (path != null && type.startsWith('video/'))
                  SizedBox(
                      height: 360,
                      child: SocialVideo(api: widget.api, path: path)),
                if (path != null &&
                    !type.startsWith('image/') &&
                    !type.startsWith('video/'))
                  TextButton(
                      onPressed: () => act(() async {
                            await openAttachmentBytes(
                                await widget.api.socialMedia(path),
                                type,
                                '${p['mediaName'] ?? 'Attachment'}');
                          }),
                      child: const Text('Open attachment')),
                Text('${p['caption'] ?? ''}'),
                Wrap(spacing: 8, children: [
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => act(() async {
                                await widget.api
                                    .toggleSocialLike(widget.postId);
                              }),
                      child: Text(
                          '${p['likedByMe'] == true ? 'Unlike' : 'Like'} (${p['likeCount']})')),
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => act(() async {
                                await widget.api
                                    .toggleSocialSave(widget.postId);
                              }),
                      child: Text(p['savedByMe'] == true ? 'Unsave' : 'Save')),
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => act(() => shareSocialTarget(
                              context, widget.api, widget.postId)),
                      child: const Text('Share'))
                ]),
                for (final c in p['comments'] as List? ?? [])
                  ListTile(
                      title: Text('${c['authorName']}'),
                      subtitle: Text('${c['message']}')),
                TextField(
                    controller: comment,
                    maxLength: 1000,
                    decoration:
                        const InputDecoration(labelText: 'Write a comment')),
                FilledButton(
                    onPressed: busy
                        ? null
                        : () => act(() async {
                              if (comment.text.trim().isEmpty) return;
                              await widget.api.addSocialComment(
                                  widget.postId, comment.text.trim());
                              comment.clear();
                            }),
                    child: const Text('Post comment'))
              ]));
  }
}
