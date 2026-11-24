import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/myaaptha_api.dart';

class ExternalFeedsScreen extends StatefulWidget {
  const ExternalFeedsScreen(
      {super.key, required this.api, this.category = 'ALL'});
  final MyAapthaApi api;
  final String category;
  @override
  State<ExternalFeedsScreen> createState() => _ExternalState();
}

class _ExternalState extends State<ExternalFeedsScreen> {
  List<Map<String, dynamic>> sources = [], items = [], people = [];
  int? more, sourceMore, peopleMore;
  bool saved = false, busy = false;
  String? error, notice;
  int sequence = 0;
  final feedUrl = TextEditingController();
  @override
  void dispose() {
    feedUrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> maps(dynamic value) =>
      (value as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({int? before}) async {
    final current = ++sequence;
    setState(() => busy = true);
    try {
      final values = await Future.wait([
        widget.api.externalItems(
            category: widget.category, saved: saved, beforeId: before),
        widget.api.externalSources(),
        widget.api.advisors('ALL')
      ]);
      if (mounted && current == sequence) {
        setState(() {
          items = [if (before != null) ...items, ...maps(values[0]['items'])];
          more = (values[0]['nextCursor'] as num?)?.toInt();
          sources = maps(values[1]['items']);
          sourceMore = (values[1]['nextCursor'] as num?)?.toInt();
          people = maps(values[2]['items']);
          peopleMore = (values[2]['nextCursor'] as num?)?.toInt();
          error = null;
        });
      }
    } catch (e) {
      if (mounted && current == sequence) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted && current == sequence) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> act(Future<void> Function() task) async {
    setState(() => busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<bool> confirm(String text) async =>
      await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('Confirm'),
                  content: Text(text),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Continue'))
                  ])) ??
      false;
  String address(String raw) {
    final value = raw.trim();
    final match = RegExp(r'^(UC[\w-]{22})$').firstMatch(value) ??
        RegExp(r'^https://(?:www\.)?youtube\.com/channel/(UC[\w-]{22})/?$')
            .firstMatch(value);
    return match == null
        ? value
        : 'https://www.youtube.com/feeds/videos.xml?channel_id=${match.group(1)}';
  }

  Future<void> connect() async {
    final url = feedUrl;
    url.clear();
    int? selected;
    String? dialogError;
    bool saving = false;
    final labels = [...people];
    int? next = peopleMore;
    final result = await showDialog<bool>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (c, update) => AlertDialog(
                    title: const Text('Connect a public feed'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      if (dialogError != null) Text(dialogError!),
                      DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Feed advisor'),
                          items: labels
                              .map((p) => DropdownMenuItem(
                                  value: (p['id'] as num).toInt(),
                                  child: Text('${p['name']}')))
                              .toList(),
                          onChanged: saving ? null : (v) => selected = v),
                      if (next != null)
                        TextButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    try {
                                      final page = await widget.api
                                          .advisors('ALL', afterId: next!);
                                      if (c.mounted) {
                                        update(() {
                                          labels.addAll(maps(page['items']));
                                          next = (page['nextCursor'] as num?)
                                              ?.toInt();
                                        });
                                      }
                                    } catch (e) {
                                      if (c.mounted) {
                                        update(() => dialogError = '$e');
                                      }
                                    }
                                  },
                            child: const Text('More advisors')),
                      TextField(
                          controller: url,
                          maxLength: 2048,
                          decoration: const InputDecoration(
                              labelText:
                                  'Public feed URL or YouTube channel ID')),
                      const Text(
                          'RSS/Atom or a YouTube UC channel ID. Public text previews are saved privately; this does not connect Instagram.')
                    ])),
                    actions: [
                      TextButton(
                          onPressed:
                              saving ? null : () => Navigator.pop(c, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (selected == null ||
                                      url.text.trim().isEmpty) {
                                    update(() => dialogError =
                                        'Choose an advisor and enter a feed address');
                                    return;
                                  }
                                  update(() => saving = true);
                                  try {
                                    await widget.api.connectExternalFeed(
                                        selected!, address(url.text));
                                    if (c.mounted) {
                                      Navigator.pop(c, true);
                                    }
                                  } catch (e) {
                                    if (c.mounted) {
                                      update(() => dialogError = '$e');
                                    }
                                  } finally {
                                    if (c.mounted) {
                                      update(() => saving = false);
                                    }
                                  }
                                },
                          child:
                              Text(saving ? 'Connecting...' : 'Connect feed'))
                    ])));
    if (result == true && mounted) {
      await load();
    }
  }

  Future<void> flags(Map<String, dynamic> item,
      {bool? save, bool? like}) async {
    await act(() async {
      final updated = await widget.api.externalFlags(
          (item['id'] as num).toInt(),
          saved: save ?? item['saved'] == true,
          liked: like ?? item['liked'] == true);
      if (mounted) {
        setState(() => items = items
            .map((p) => p['id'] == item['id'] ? updated : p)
            .where((p) => !saved || p['saved'] == true)
            .toList());
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('External advisor feeds')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          FilledButton(
              onPressed: busy ? null : connect,
              child: const Text('Connect a public feed')),
          TextButton(
              onPressed: busy ? null : () => load(),
              child: const Text('Refresh posts')),
          FilterChip(
              label: const Text('Saved external posts'),
              selected: saved,
              onSelected: busy
                  ? null
                  : (v) {
                      setState(() => saved = v);
                      load();
                    })
        ]),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        if (notice != null) Text(notice!),
        ExpansionTile(
            title: Text(
                'Connected feeds (${sources.length}${sourceMore != null ? '+' : ''})'),
            children: [
              ...sources.map((s) => ListTile(
                  title: Text('${s['title']}'),
                  subtitle: Text(s['error'] as String? ??
                      (s['lastSuccess'] == null
                          ? 'Not refreshed yet'
                          : 'Updated ${s['lastSuccess']}')),
                  trailing: PopupMenuButton<String>(
                      enabled: !busy,
                      onSelected: (value) => act(() async {
                            if (value == 'refresh') {
                              await widget.api.refreshExternalFeed(
                                  (s['id'] as num).toInt());
                            } else if (value == 'state') {
                              await widget.api.externalSourceState(
                                  (s['id'] as num).toInt(),
                                  s['enabled'] != true);
                            } else {
                              if (!await confirm(
                                  'Disconnect this feed and remove imported previews and saves?')) {
                                return;
                              }
                              await widget.api
                                  .removeExternalFeed((s['id'] as num).toInt());
                            }
                            await load();
                          }),
                      itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'refresh', child: Text('Refresh feed')),
                            PopupMenuItem(
                                value: 'state',
                                child: Text(s['enabled'] == true
                                    ? 'Pause feed'
                                    : 'Resume feed')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Disconnect'))
                          ]))),
              if (sourceMore != null)
                TextButton(
                    onPressed: busy
                        ? null
                        : () => act(() async {
                              final page = await widget.api
                                  .externalSources(afterId: sourceMore!);
                              if (mounted) {
                                setState(() {
                                  sources.addAll(maps(page['items']));
                                  sourceMore =
                                      (page['nextCursor'] as num?)?.toInt();
                                });
                              }
                            }),
                    child: const Text('More connected feeds'))
            ]),
        if (!busy && items.isEmpty)
          Text(saved
              ? 'No saved external posts.'
              : 'Connect an advisor public feed to see their latest previews.'),
        ...items.map((p) => Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p['sourceName']}'),
                      Text('${p['title']}',
                          style: Theme.of(context).textTheme.titleMedium),
                      if ((p['summary'] as String? ?? '').isNotEmpty)
                        Text('${p['summary']}'),
                      Wrap(spacing: 8, children: [
                        TextButton(
                            onPressed: () => act(() async {
                                  if (!await launchUrl(
                                      Uri.parse(p['url'] as String),
                                      mode: LaunchMode.externalApplication)) {
                                    throw StateError(
                                        'Could not open original post');
                                  }
                                }),
                            child: const Text('Read original')),
                        TextButton(
                            onPressed: busy
                                ? null
                                : () => flags(p, like: p['liked'] != true),
                            child: Text(p['liked'] == true
                                ? 'Liked in MyAaptha'
                                : 'Like in MyAaptha')),
                        TextButton(
                            onPressed: busy
                                ? null
                                : () => flags(p, save: p['saved'] != true),
                            child:
                                Text(p['saved'] == true ? 'Unsave' : 'Save')),
                        TextButton(
                            onPressed: () => act(() async {
                                  await Clipboard.setData(
                                      ClipboardData(text: p['url'] as String));
                                  if (mounted) {
                                    setState(() => notice =
                                        'Link copied. You can paste it into a chat.');
                                  }
                                }),
                            child: const Text('Copy link')),
                        TextButton(
                            onPressed: busy
                                ? null
                                : () => act(() async {
                                      if (await confirm(
                                          'Share this title and original link publicly in your MyAaptha feed?')) {
                                        await widget.api.repostExternalLink(
                                            (p['id'] as num).toInt());
                                        if (mounted) {
                                          setState(() => notice =
                                              'Original link shared in your feed.');
                                        }
                                      }
                                    }),
                            child: const Text('Repost link'))
                      ])
                    ])))),
        if (more != null)
          TextButton(
              onPressed: busy ? null : () => load(before: more),
              child: const Text('Load more external posts'))
      ]));
}
