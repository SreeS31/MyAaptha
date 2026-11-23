import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'social_post_screen.dart';
import 'social_video.dart';

Future<String?> socialText(BuildContext context, String title,
    {String initial = '', int maxLength = 80}) async {
  final text = TextEditingController(text: initial);
  final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
              title: Text(title),
              content: TextField(
                  controller: text, maxLength: maxLength, autofocus: true),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, text.text.trim()),
                    child: const Text('Save'))
              ]));
  text.dispose();
  return result;
}

class SocialToolsScreen extends StatefulWidget {
  const SocialToolsScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<SocialToolsScreen> createState() => _SocialToolsScreenState();
}

class _SocialToolsScreenState extends State<SocialToolsScreen> {
  String section = 'Archive', query = '';
  List<Map<String, dynamic>> rows = [],
      friends = [],
      candidates = [],
      posts = [];
  String? collection;
  int? more;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      if (section == 'Close Friends') {
        final selected = await widget.api.socialToolList('close-friends');
        final relations = await widget.api.relationships();
        if (mounted) {
          setState(() {
            friends = selected;
            candidates = {
              for (final p in [
                ...selected,
                ...relations
                    .where((r) =>
                        r.person.accountStatus == 'ACTIVE' &&
                        r.person.identityType != 'MANAGED')
                    .map((r) =>
                        {'id': r.person.id, 'name': r.person.displayName})
              ])
                p['id']: p
            }.values.toList();
          });
        }
      } else {
        final path = section == 'Archive'
            ? 'archive'
            : section == 'Highlights'
                ? 'highlights'
                : 'collections';
        final next = await widget.api.socialToolList(path);
        if (mounted) setState(() => rows = next);
      }
      if (mounted) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> showCollection(String name, {int? before}) async {
    setState(() => busy = true);
    try {
      final page = await widget.api.socialCollectionPosts(name, before: before);
      if (mounted) {
        setState(() {
          collection = name;
          final next = (page['items'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          posts = before == null ? next : [...posts, ...next];
          more = page['hasNext'] == true
              ? (page['nextBefore'] as num?)?.toInt()
              : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Social library'), actions: [
        IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh))
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          for (final name in [
            'Close Friends',
            'Archive',
            'Highlights',
            'Collections'
          ])
            ChoiceChip(
                label: Text(name),
                selected: section == name,
                onSelected: busy
                    ? null
                    : (_) {
                        setState(() {
                          section = name;
                          collection = null;
                          rows = [];
                          posts = [];
                        });
                        load();
                      })
        ]),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (busy) const LinearProgressIndicator(),
        if (section == 'Close Friends') ...[
          const Text(
              'Only selected people can see posts and stories shared with Close Friends.'),
          TextField(
              decoration: const InputDecoration(labelText: 'Find people'),
              onChanged: (v) => setState(() => query = v.toLowerCase())),
          for (final person in candidates
              .where((p) => '${p['name']}'.toLowerCase().contains(query)))
            CheckboxListTile(
                title: Text('${person['name']}'),
                value: friends.any((f) => f['id'] == person['id']),
                onChanged: busy
                    ? null
                    : (chosen) async {
                        setState(() => busy = true);
                        try {
                          await widget.api.setCloseFriend(
                              (person['id'] as num).toInt(), chosen == true);
                          await load();
                        } catch (e) {
                          if (mounted) setState(() => error = '$e');
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      })
        ] else if (section == 'Collections') ...[
          for (final row in rows)
            ListTile(
                title: Text('${row['name']}'),
                subtitle: Text('${row['count']} saved posts'),
                onTap: () => showCollection('${row['name']}')),
          if (collection != null)
            Text(collection!, style: Theme.of(context).textTheme.titleLarge),
          for (final post in posts)
            ListTile(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SocialPostScreen(
                            api: widget.api,
                            postId: (post['id'] as num).toInt()))),
                title: Text(
                    '${post['caption'] ?? post['mediaName'] ?? 'Saved post'}'),
                subtitle: Text('${post['authorName']}'),
                trailing: IconButton(
                    tooltip: 'Remove from collection',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: busy
                        ? null
                        : () async {
                            try {
                              await widget.api.removeSocialCollection(
                                  (post['id'] as num).toInt(), collection!);
                              await showCollection(collection!);
                              await load();
                            } catch (e) {
                              if (mounted) setState(() => error = '$e');
                            }
                          })),
          if (more != null)
            TextButton(
                onPressed: busy
                    ? null
                    : () => showCollection(collection!, before: more),
                child: const Text('Load more'))
        ] else ...[
          Text(section == 'Archive'
              ? 'Stories you chose to archive; unhighlighted copies expire after 30 days.'
              : 'Highlights keep their original audience and media storage expiry.'),
          for (final story in rows)
            ListTile(
                title: Text(
                    '${story['highlightName'] ?? story['caption'] ?? 'Story'}'),
                subtitle: Text('${story['authorName']}'),
                leading: const Icon(Icons.auto_stories_outlined),
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SocialStoryScreen(
                              api: widget.api, story: story)));
                  await load();
                })
        ],
        if (!busy && section != 'Close Friends' && rows.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24), child: Text('Nothing here yet.'))
      ]));
}

class SocialStoryScreen extends StatefulWidget {
  const SocialStoryScreen({super.key, required this.api, required this.story});
  final MyAapthaApi api;
  final Map<String, dynamic> story;
  @override
  State<SocialStoryScreen> createState() => _SocialStoryScreenState();
}

class _SocialStoryScreenState extends State<SocialStoryScreen> {
  late Map<String, dynamic> story = Map.from(widget.story);
  Map<String, dynamic> reactions = {};
  List<Map<String, dynamic>>? viewers;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final id = (story['id'] as num).toInt();
      if (story['mine'] != true) {
        story.addAll(await widget.api.viewSocialStory(id));
      }
      final next = await widget.api.storyReactions(id);
      if (mounted) setState(() => reactions = next);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> action(Future<void> Function() task) async {
    setState(() => busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = story['mediaUrl'] as String?,
        type = '${story['mediaType']}',
        id = (story['id'] as num).toInt();
    return Scaffold(
        appBar: AppBar(title: Text('${story['authorName']}')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (error != null)
            Text(error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (path != null && type.startsWith('image/'))
            FutureBuilder(
                future: widget.api.socialMedia(path),
                builder: (context, snap) => snap.hasData
                    ? InteractiveViewer(
                        child: Image.memory(snap.data!, fit: BoxFit.contain))
                    : const LinearProgressIndicator()),
          if (path != null && type.startsWith('video/'))
            SizedBox(
                height: 420, child: SocialVideo(api: widget.api, path: path)),
          if ('${story['caption'] ?? ''}'.isNotEmpty)
            Text('${story['caption']}',
                style: Theme.of(context).textTheme.headlineSmall),
          Wrap(spacing: 8, children: [
            for (final emoji in ['👍', '❤️', '😂', '😮', '😢', '🙏'])
              ChoiceChip(
                  label: Text(
                      '$emoji ${(reactions['counts'] as Map?)?[emoji] ?? ''}'),
                  selected: reactions['mine'] == emoji,
                  onSelected: busy ||
                          (story['highlightName'] == null &&
                              !DateTime.parse('${story['expiresAt']}')
                                  .isAfter(DateTime.now()))
                      ? null
                      : (_) => action(() async {
                            final next = await widget.api.reactStory(
                                id, reactions['mine'] == emoji ? null : emoji);
                            if (mounted) setState(() => reactions = next);
                          }))
          ]),
          if (story['mine'] != true)
            FilledButton.tonal(
                onPressed: busy
                    ? null
                    : () async {
                        final text = await socialText(
                            context, 'Reply privately',
                            maxLength: 1000);
                        if (text == null || text.isEmpty) return;
                        await action(() async {
                          await widget.api.replyToStory(id, text);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Reply sent in Messages.')));
                          }
                        });
                      },
                child: const Text('Reply privately')),
          if (story['mine'] == true) ...[
            TextButton(
                onPressed: busy
                    ? null
                    : () => action(() async {
                          final next = await widget.api
                              .socialToolList('stories/$id/viewers');
                          if (mounted) setState(() => viewers = next);
                        }),
                child: Text('Viewers (${story['viewCount']})')),
            TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final name = await socialText(
                            context, 'Highlight name (blank to remove)',
                            initial: '${story['highlightName'] ?? ''}');
                        if (name == null) return;
                        await action(() async {
                          await widget.api.highlightStory(id, name);
                          if (mounted) {
                            setState(() => story['highlightName'] =
                                name.isEmpty ? null : name);
                          }
                        });
                      },
                child: Text(story['highlightName'] == null
                    ? 'Add to highlights'
                    : 'Edit highlight')),
            TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final yes = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                                    title: const Text('Delete story?'),
                                    content: const Text(
                                        'This removes its archive and highlight too.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text('Cancel')),
                                      FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text('Delete'))
                                    ]));
                        if (yes == true) {
                          await action(() async {
                            await widget.api.deleteSocialStory(id);
                            if (context.mounted) Navigator.pop(context);
                          });
                        }
                      },
                child: const Text('Delete story'))
          ],
          if (viewers != null) ...[
            for (final viewer in viewers!)
              ListTile(title: Text('${viewer['name']}')),
            if (viewers!.isEmpty) const Text('No viewers yet.')
          ]
        ]));
  }
}
