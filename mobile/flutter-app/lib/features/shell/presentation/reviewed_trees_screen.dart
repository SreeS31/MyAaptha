import 'dart:async';
import 'dart:convert';
import 'reviewed_tree_canvas.dart';
import 'package:flutter/material.dart';
import '../../../core/network/myaaptha_api.dart';

class ReviewedTreesScreen extends StatefulWidget {
  const ReviewedTreesScreen(
      {super.key,
      required this.api,
      this.saved = false,
      this.embedded = false});
  final MyAapthaApi api;
  final bool saved, embedded;
  @override
  State<ReviewedTreesScreen> createState() => _ReviewedTreesState();
}

class _ReviewedTreesState extends State<ReviewedTreesScreen> {
  List<Map<String, dynamic>> cards = [];
  Map<String, dynamic>? summary;
  int? more;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant ReviewedTreesScreen old) {
    super.didUpdateWidget(old);
    if (old.saved != widget.saved) {
      load();
    }
  }

  Future<void> load({int cursor = 0}) async {
    setState(() => busy = true);
    try {
      final value = widget.saved
          ? await widget.api.savedRelationshipTrees(afterId: cursor)
          : await widget.api.suggestedRelationshipTrees(offset: cursor);
      if (mounted) {
        setState(() {
          summary = value;
          cards = [
            if (cursor > 0) ...cards,
            ...(value['items'] as List)
                .map((row) => Map<String, dynamic>.from(row as Map))
          ];
          more = (value[widget.saved ? 'nextCursor' : 'nextOffset'] as num?)
              ?.toInt();
          error = null;
        });
      }
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

  Future<void> open(Map<String, dynamic>? card) async {
    setState(() => busy = true);
    try {
      final tree = card == null
          ? <String, dynamic>{
              'id': null,
              'sourceKey': null,
              'name': 'My tree',
              'reason': 'Created by me',
              'nodes': <Map<String, dynamic>>[],
              'version': 0
            }
          : await widget.api.reviewedRelationshipTree(
              '${card['id'] ?? card['key']}',
              saved: card['id'] != null);
      if (!mounted) {
        return;
      }
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ReviewedTreeEditor(api: widget.api, tree: tree)));
      if (mounted) {
        await load();
      }
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

  @override
  Widget build(BuildContext context) {
    final body = ListView(padding: const EdgeInsets.all(16), children: [
      Text(widget.saved ? 'My trees' : 'Suggested trees',
          style: Theme.of(context).textTheme.headlineSmall),
      if (!widget.saved && summary != null)
        Text(
            "${summary!['scannedContacts']} contacts reviewed; ${summary!['totalSuggestions']} suggestions; at least 3 people per tree"),
      Wrap(spacing: 8, children: [
        FilledButton(
            onPressed: busy ? null : () => open(null),
            child: const Text('Create a tree')),
        TextButton(
            onPressed: busy ? null : () => load(),
            child: const Text('Refresh')),
        if (!widget.saved && (summary?['dismissedCount'] as num? ?? 0) > 0)
          TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      try {
                        await widget.api.restoreRelationshipTrees();
                        await load();
                      } catch (e) {
                        if (mounted) {
                          setState(() => error = '$e');
                        }
                      }
                    },
              child: const Text('Restore dismissed'))
      ]),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      if (!busy && cards.isEmpty)
        Text(widget.saved
            ? 'Save a suggestion or create your own tree.'
            : 'No groups with at least 3 people have enough shared clues yet. You can create a tree manually.'),
      ...cards.map((card) => Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${card['name']}',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text("${card['count']} people; ${card['confidence']}"),
                    Text('${card['reason']}'),
                    const Chip(label: Text('You')),
                    ...(card['preview'] as List).map((node) => Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 6),
                        child: Text(
                            "\u2514 ${node['name']}; ${node['relation']}"))),
                    Wrap(spacing: 8, children: [
                      TextButton(
                          onPressed: busy ? null : () => open(card),
                          child: Text(card['id'] == null
                              ? 'Review tree'
                              : 'Open tree')),
                      TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  if (card['id'] != null) {
                                    final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                                title:
                                                    const Text('Delete tree?'),
                                                content: const Text(
                                                    'Your contacts stay in your address book.'),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              c, false),
                                                      child:
                                                          const Text('Cancel')),
                                                  FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              c, true),
                                                      child:
                                                          const Text('Delete'))
                                                ]));
                                    if (confirmed != true) {
                                      return;
                                    }
                                  }
                                  try {
                                    if (card['id'] == null) {
                                      await widget.api.dismissRelationshipTree(
                                          card['key'] as String);
                                    } else {
                                      await widget.api
                                          .deleteReviewedRelationshipTree(
                                              (card['id'] as num).toInt());
                                    }
                                    await load();
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() => error = '$e');
                                    }
                                  }
                                },
                          child: Text(
                              card['id'] == null ? 'Dismiss' : 'Delete tree'))
                    ])
                  ])))),
      if (more != null)
        TextButton(
            onPressed: busy ? null : () => load(cursor: more!),
            child: const Text('Load more trees'))
    ]);
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Relationship trees')),
            body: body);
  }
}

class ReviewedTreeEditor extends StatefulWidget {
  const ReviewedTreeEditor({super.key, required this.api, required this.tree});
  final MyAapthaApi api;
  final Map<String, dynamic> tree;
  @override
  State<ReviewedTreeEditor> createState() => _TreeEditorState();
}

class _TreeEditorState extends State<ReviewedTreeEditor> {
  late Map<String, dynamic> tree;
  late final TextEditingController title;
  final name = TextEditingController(),
      relation = TextEditingController(),
      search = TextEditingController();
  String? selected, error;
  bool reviewed = false, busy = false, dirty = false;

  List<Map<String, dynamic>> get nodes =>
      (tree['nodes'] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic>? get active {
    for (final node in nodes) {
      if (node['key'] == selected) {
        return node;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    tree =
        Map<String, dynamic>.from(jsonDecode(jsonEncode(widget.tree)) as Map);
    tree['nodes'] = (tree['nodes'] as List)
        .map((n) => Map<String, dynamic>.from(n as Map))
        .toList();
    title = TextEditingController(text: tree['name'] as String);
  }

  @override
  void dispose() {
    title.dispose();
    name.dispose();
    relation.dispose();
    search.dispose();
    super.dispose();
  }

  void change(VoidCallback task) {
    setState(() {
      task();
      dirty = true;
      reviewed = false;
    });
  }

  void select(Map<String, dynamic> node) {
    name.text = node['name'] as String;
    relation.text = node['relation'] as String;
    setState(() => selected = node['key'] as String);
  }

  Future<void> close() async {
    if (dirty) {
      final yes = await showDialog<bool>(
          context: context,
          builder: (c) =>
              AlertDialog(title: const Text('Discard changes?'), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Keep editing')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Discard'))
              ]));
      if (yes != true) {
        return;
      }
    }
    if (mounted) {
      setState(() => dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  List<Map<String, dynamic>> parents(Map<String, dynamic> node) {
    final byKey = {for (final value in nodes) value['key']: value};
    return nodes.where((candidate) {
      Map<String, dynamic>? current = candidate;
      final seen = <String>{};
      while (current != null) {
        final key = current['key'] as String;
        if (key == node['key'] || !seen.add(key)) {
          return false;
        }
        current = byKey[current['parentKey']];
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final current = active;
    return PopScope(
        canPop: !dirty && !busy,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !busy) {
            close();
          }
        },
        child: Scaffold(
            appBar: AppBar(
                title: Text(tree['id'] == null ? 'Review tree' : 'Edit tree'),
                leading: IconButton(
                    tooltip: 'Close tree',
                    onPressed: busy ? null : close,
                    icon: const Icon(Icons.arrow_back))),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              TextField(
                  controller: title,
                  enabled: !busy,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Tree name'),
                  onChanged: (_) => change(() {})),
              Text('${tree['reason']}'),
              const Text(
                  'Private tree; no invitations or messaging members are added.'),
              Wrap(spacing: 8, children: [
                TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final picked =
                                await showDialog<List<Map<String, dynamic>>>(
                                    context: context,
                                    builder: (_) => _TreeContactPicker(
                                        api: widget.api,
                                        excluded: nodes
                                            .where(
                                                (n) => n['contactId'] != null)
                                            .map((n) =>
                                                (n['contactId'] as num).toInt())
                                            .toSet()));
                            if (picked != null && mounted) {
                              change(() {
                                for (final contact in picked) {
                                  nodes.add({
                                    'key': "c${contact['id']}",
                                    'contactId': contact['id'],
                                    'name': contact['name'],
                                    'relation': 'Connection',
                                    'parentKey': null
                                  });
                                }
                              });
                            }
                          },
                    child: const Text('Add from contacts')),
                TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            final node = <String, dynamic>{
                              'key':
                                  'n${DateTime.now().microsecondsSinceEpoch}',
                              'contactId': null,
                              'name': 'New person',
                              'relation': 'Connection',
                              'parentKey': null
                            };
                            change(() => nodes.add(node));
                            select(node);
                          },
                    child: const Text('Add a person')),
                Text('${nodes.length} people')
              ]),
              TextField(
                  controller: search,
                  decoration: const InputDecoration(labelText: 'Find a node'),
                  onChanged: (_) => setState(() {})),
              if (search.text.isNotEmpty)
                ...nodes
                    .where((n) => (n['name'] as String)
                        .toLowerCase()
                        .contains(search.text.toLowerCase()))
                    .take(50)
                    .map((n) => TextButton(
                        onPressed: () => select(n),
                        child: Text('${n['name']}'))),
              if (current != null)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          TextField(
                              controller: name,
                              maxLength: 200,
                              enabled: !busy,
                              decoration: const InputDecoration(
                                  labelText: 'Person name'),
                              onChanged: (value) =>
                                  change(() => current['name'] = value)),
                          TextField(
                              controller: relation,
                              maxLength: 80,
                              enabled: !busy,
                              decoration: const InputDecoration(
                                  labelText:
                                      'Relationship to connection point'),
                              onChanged: (value) =>
                                  change(() => current['relation'] = value)),
                          DropdownButtonFormField<String>(
                              key: ValueKey('$selected-${current['gender']}'),
                              initialValue:
                                  current['gender'] as String? ?? 'UNSPECIFIED',
                              decoration:
                                  const InputDecoration(labelText: 'Gender'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'UNSPECIFIED',
                                    child: Text('Unspecified')),
                                DropdownMenuItem(
                                    value: 'MALE', child: Text('Man')),
                                DropdownMenuItem(
                                    value: 'FEMALE', child: Text('Woman')),
                                DropdownMenuItem(
                                    value: 'OTHER', child: Text('Other'))
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) =>
                                      change(() => current['gender'] = value)),
                          DropdownButtonFormField<String>(
                              key:
                                  ValueKey('$selected-${current['parentKey']}'),
                              isExpanded: true,
                              initialValue:
                                  current['parentKey'] as String? ?? '',
                              decoration: const InputDecoration(
                                  labelText: 'Connected under'),
                              items: [
                                const DropdownMenuItem(
                                    value: '', child: Text('You')),
                                ...parents(current).map((n) => DropdownMenuItem(
                                    value: n['key'] as String,
                                    child: Text('${n['name']}',
                                        overflow: TextOverflow.ellipsis)))
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) => change(() =>
                                      current['parentKey'] =
                                          value == '' ? null : value)),
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => change(() {
                                        nodes.removeWhere(
                                            (n) => n['key'] == selected);
                                        for (final n in nodes) {
                                          if (n['parentKey'] == selected) {
                                            n['parentKey'] = null;
                                            n['relation'] = 'Connection';
                                          }
                                        }
                                        selected = null;
                                      }),
                              child: const Text('Remove node'))
                        ]))),
              ReviewedTreeCanvas(
                  nodes: nodes, selected: selected, onSelect: select),
              CheckboxListTile(
                  title: const Text('I reviewed these connections'),
                  value: reviewed,
                  onChanged: busy
                      ? null
                      : (value) => setState(() => reviewed = value == true)),
              if (nodes.length < 3)
                const Text('Add at least 3 people to save.'),
              FilledButton(
                  onPressed: busy ||
                          !reviewed ||
                          nodes.length < 3 ||
                          title.text.trim().isEmpty ||
                          nodes.any((n) =>
                              (n['name'] as String).trim().isEmpty ||
                              (n['relation'] as String).trim().isEmpty)
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            await widget.api.saveReviewedRelationshipTree(
                                {...tree, 'name': title.text.trim()});
                            if (mounted) {
                              setState(() {
                                dirty = false;
                                busy = false;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => error = '$e');
                            }
                          } finally {
                            if (mounted) {
                              setState(() => busy = false);
                            }
                          }
                        },
                  child: const Text('Save reviewed tree'))
            ])));
  }
}

class _TreeContactPicker extends StatefulWidget {
  const _TreeContactPicker({required this.api, required this.excluded});
  final MyAapthaApi api;
  final Set<int> excluded;
  @override
  State<_TreeContactPicker> createState() => _PickerState();
}

class _PickerState extends State<_TreeContactPicker> {
  final search = TextEditingController();
  final selected = <int, Map<String, dynamic>>{};
  List<Map<String, dynamic>> contacts = [];
  int? cursor;
  int sequence = 0;
  String? error;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    final request = ++sequence;
    try {
      final value = await widget.api.relationshipTreeContacts(
          query: search.text, afterId: more ? cursor ?? 0 : 0);
      if (mounted && request == sequence) {
        setState(() {
          contacts = [
            if (more) ...contacts,
            ...(value['items'] as List)
                .map((v) => Map<String, dynamic>.from(v as Map))
          ];
          cursor = (value['nextCursor'] as num?)?.toInt();
          error = null;
        });
      }
    } catch (e) {
      if (mounted && request == sequence) {
        setState(() => error = '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Add tree contacts'),
          content: SizedBox(
              width: 500,
              height: 420,
              child: Column(children: [
                TextField(
                    controller: search,
                    decoration:
                        const InputDecoration(labelText: 'Find a contact'),
                    onChanged: (_) {
                      timer?.cancel();
                      sequence++;
                      setState(() {
                        cursor = null;
                        contacts = [];
                      });
                      timer = Timer(
                          const Duration(milliseconds: 250), () => load());
                    }),
                if (error != null) Text(error!),
                Expanded(
                    child: ListView(children: [
                  ...contacts.map((c) {
                    final id = (c['id'] as num).toInt();
                    return CheckboxListTile(
                        title: Text('${c['name']}'),
                        value: selected.containsKey(id) ||
                            widget.excluded.contains(id),
                        onChanged: widget.excluded.contains(id)
                            ? null
                            : (value) => setState(() {
                                  if (value == true) {
                                    selected[id] = c;
                                  } else {
                                    selected.remove(id);
                                  }
                                }));
                  }),
                  if (cursor != null)
                    TextButton(
                        onPressed: () => load(more: true),
                        child: const Text('More contacts'))
                ]))
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, selected.values.toList()),
                child: Text('Add ${selected.length}'))
          ]);
}
