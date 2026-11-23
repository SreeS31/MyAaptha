import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'social_video.dart';
import 'social_media_picker.dart';
import 'social_post_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  List<Map<String, dynamic>> posts = [];
  int? more;
  int active = 0;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({int? before}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final page = await widget.api.socialBrowse('REELS', before: before);
      if (mounted) {
        setState(() {
          final rows = (page['items'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          posts = before == null ? rows : [...posts, ...rows];
          more = page['hasNext'] == true
              ? (page['nextBefore'] as num?)?.toInt()
              : null;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(int index, bool like) async {
    try {
      final p = posts[index], id = (p['id'] as num).toInt();
      final next = like
          ? await widget.api.toggleSocialLike(id)
          : await widget.api.toggleSocialSave(id);
      if (mounted) setState(() => posts[index] = next);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> upload() async {
    PlatformFile? file;
    try {
      file = await pickSocialMedia(FileType.video);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
      return;
    }
    if (file?.bytes == null || !mounted) return;
    final caption = TextEditingController();
    var audience = 'RELATIONSHIPS';
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Share a video'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: caption,
                      maxLength: 4000,
                      decoration: const InputDecoration(labelText: 'Caption')),
                  DropdownButtonFormField<String>(
                      initialValue: audience,
                      decoration: const InputDecoration(labelText: 'Audience'),
                      items: const [
                        DropdownMenuItem(
                            value: 'RELATIONSHIPS', child: Text('Connections')),
                        DropdownMenuItem(
                            value: 'CLOSE_FRIENDS',
                            child: Text('Close Friends')),
                        DropdownMenuItem(value: 'PUBLIC', child: Text('Public'))
                      ],
                      onChanged: (value) => audience = value!)
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Share'))
                ]));
    final text = caption.text.trim();
    caption.dispose();
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.api.createReel(text,audience,file!.bytes!,file.name);
      if (mounted) setState(() => busy = false);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Reels'), actions: [
        IconButton(
            tooltip: 'Share a video',
            onPressed: busy ? null : upload,
            icon: const Icon(Icons.video_call_outlined)),
        IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh))
      ]),
      body: Column(children: [
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (busy) const LinearProgressIndicator(),
        if (!busy && posts.isEmpty)
          const Expanded(child: Center(child: Text('No shared videos yet.')))
        else
          Expanded(
              child: PageView.builder(
                  scrollDirection: Axis.vertical,
                  onPageChanged: (index) {
                    setState(() => active = index);
                    if (index >= posts.length - 2 && more != null) {
                      load(before: more);
                    }
                  },
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final p = posts[index];
                    return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          Expanded(
                              child: SocialVideo(
                                  key: ValueKey(p['id']),
                                  api: widget.api,
                                  path: '${p['mediaUrl']}',
                                  active: active == index,
                                  autoplay: true)),
                          ListTile(
                              title: Text('${p['authorName']}'),
                              subtitle: Text('${p['caption'] ?? ''}',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis)),
                          Wrap(spacing: 8, children: [
                            TextButton(
                                onPressed: () => action(index, true),
                                child: Text(
                                    '${p['likedByMe'] == true ? 'Unlike' : 'Like'} (${p['likeCount']})')),
                            TextButton(
                                onPressed: () => action(index, false),
                                child: Text(p['savedByMe'] == true
                                    ? 'Unsave'
                                    : 'Save')),
                            TextButton(
                                onPressed: () async {
                                  setState(() => active = -1);
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => SocialPostScreen(
                                              api: widget.api,
                                              postId:
                                                  (p['id'] as num).toInt())));
                                  if (mounted) setState(() => active = index);
                                },
                                child: const Text('Comments')),
                            TextButton(
                                onPressed: () async {
                                  try {
                                    await shareSocialTarget(context, widget.api,
                                        (p['id'] as num).toInt());
                                  } catch (e) {
                                    if (mounted) setState(() => error = '$e');
                                  }
                                },
                                child: const Text('Share'))
                          ])
                        ]));
                  }))
      ]));
}
