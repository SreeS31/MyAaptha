import 'external_feeds_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/myaaptha_api.dart';

class AdvisorsScreen extends StatefulWidget {
  const AdvisorsScreen(
      {super.key, required this.api, required this.postsBuilder});
  final MyAapthaApi api;
  final Widget Function(String category) postsBuilder;
  @override
  State<AdvisorsScreen> createState() => _AdvisorsState();
}

class _AdvisorsState extends State<AdvisorsScreen> {
  List<Map<String, dynamic>> categories = [], people = [];
  String category = 'ALL';
  int? more;
  bool busy = false;
  String? error;
  int sequence = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({int cursor = 0}) async {
    final current = ++sequence;
    setState(() => busy = true);
    try {
      final labels = await widget.api.advisorCategories(),
          page = await widget.api.advisors(category, afterId: cursor);
      if (mounted && current == sequence) {
        setState(() {
          categories = labels;
          people = [
            if (cursor > 0) ...people,
            ...(page['items'] as List)
                .map((value) => Map<String, dynamic>.from(value as Map))
          ];
          more = (page['nextCursor'] as num?)?.toInt();
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

  Map<String, dynamic> input(Map<String, dynamic> person, {bool? follow}) => {
        'memberId': person['memberId'],
        'contactId': person['contactId'],
        'name': person['name'],
        'url': person['url'],
        'notes': person['notes'],
        'categories': person['categories'],
        'followPosts': follow ?? person['followPosts'],
        'version': person['version']
      };
  Future<void> edit([Map<String, dynamic>? person]) async {
    final changed = await showDialog<bool>(
        context: context,
        builder: (_) => _AdvisorEditor(
            api: widget.api,
            categories: categories,
            category: category,
            person: person));
    if (changed == true && mounted) {
      await load();
    }
  }

  Future<void> newCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('New advisor category'),
                content: TextField(
                    controller: controller,
                    maxLength: 100,
                    decoration:
                        const InputDecoration(labelText: 'Category name')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, controller.text.trim()),
                      child: const Text('Add'))
                ]));
    controller.dispose();
    if (name == null || name.isEmpty) {
      return;
    }
    try {
      await widget.api.createAdvisorCategory(name);
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        Text('Advisors & well-wishers',
            style: Theme.of(context).textTheme.headlineSmall),
        const Text('Private lists of people you choose for guidance.'),
        Wrap(spacing: 8, children: [
          FilledButton(
              onPressed: busy ? null : () => edit(),
              child: const Text('Add a person')),
          TextButton(
              onPressed: busy ? null : newCategory,
              child: const Text('New category')),
          TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Advisors')),
                          body: widget.postsBuilder(category)))),
              child: const Text('Posts')),
          TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ExternalFeedsScreen(
                          api: widget.api, category: category))),
              child: const Text('External feeds'))
        ]),
        DropdownButtonFormField<String>(
            key: ValueKey(category),
            isExpanded: true,
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Advisor category'),
            items: [
              const DropdownMenuItem(
                  value: 'ALL', child: Text('All categories')),
              ...categories.map((c) => DropdownMenuItem(
                  value: c['key'] as String,
                  child: Text("${c['name']} (${c['people']})",
                      overflow: TextOverflow.ellipsis)))
            ],
            onChanged: busy
                ? null
                : (value) {
                    setState(() => category = value!);
                    load();
                  }),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (!busy && people.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                  'Add as many advisors as you like. Their visible MyAaptha posts will appear in Posts.')),
        ...people.map((person) => Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                              child: Text(
                                  (person['name'] as String).substring(0, 1))),
                          title: Text('${person['name']}'),
                          subtitle: Text(person['kind'] == 'MEMBER'
                              ? 'MyAaptha member'
                              : person['kind'] == 'CONTACT'
                                  ? 'Private contact'
                                  : 'Profile card')),
                      Wrap(
                          spacing: 5,
                          children: (person['categories'] as List)
                              .map((key) => Chip(
                                  label: Text(categories
                                          .where((c) => c['key'] == key)
                                          .map((c) => c['name'])
                                          .firstOrNull
                                          ?.toString() ??
                                      '$key')))
                              .toList()),
                      if ((person['notes'] as String? ?? '').isNotEmpty)
                        Text('${person['notes']}'),
                      if (person['url'] != null)
                        TextButton(
                            onPressed: () async {
                              final opened = await launchUrl(
                                  Uri.parse(person['url'] as String),
                                  mode: LaunchMode.externalApplication);
                              if (!opened && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'This profile link could not be opened.')));
                              }
                            },
                            child: const Text('Open profile')),
                      if (person['kind'] == 'MEMBER')
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Follow MyAaptha posts'),
                            value: person['followPosts'] == true,
                            onChanged: busy
                                ? null
                                : (value) async {
                                    setState(() => busy = true);
                                    try {
                                      await widget.api.saveAdvisor(
                                          input(person, follow: value),
                                          id: (person['id'] as num).toInt());
                                      await load();
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() => error = '$e');
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => busy = false);
                                      }
                                    }
                                  }),
                      Wrap(spacing: 8, children: [
                        TextButton(
                            onPressed: busy ? null : () => edit(person),
                            child: const Text('Edit')),
                        TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    final yes = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                                title: const Text(
                                                    'Remove advisor?'),
                                                content: const Text(
                                                    'This only removes them from your private advisor lists.'),
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
                                                          const Text('Remove'))
                                                ]));
                                    if (yes != true) {
                                      return;
                                    }
                                    try {
                                      await widget.api.removeAdvisor(
                                          (person['id'] as num).toInt());
                                      await load();
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() => error = '$e');
                                      }
                                    }
                                  },
                            child: const Text('Remove'))
                      ])
                    ])))),
        if (more != null)
          TextButton(
              onPressed: busy ? null : () => load(cursor: more!),
              child: const Text('Load more people'))
      ]);
}

class _AdvisorEditor extends StatefulWidget {
  const _AdvisorEditor(
      {required this.api,
      required this.categories,
      required this.category,
      this.person});
  final MyAapthaApi api;
  final List<Map<String, dynamic>> categories;
  final String category;
  final Map<String, dynamic>? person;
  @override
  State<_AdvisorEditor> createState() => _AdvisorEditorState();
}

class _AdvisorEditorState extends State<_AdvisorEditor> {
  final name = TextEditingController(),
      url = TextEditingController(),
      notes = TextEditingController(),
      query = TextEditingController();
  late String kind;
  late bool follow;
  late Set<String> selected;
  Map<String, dynamic>? chosen;
  List<Map<String, dynamic>> matches = [];
  int? cursor;
  bool busy = false;
  String? error;
  Timer? timer;
  int sequence = 0;
  @override
  void initState() {
    super.initState();
    final person = widget.person;
    kind = person?['kind'] as String? ?? 'MEMBER';
    name.text = person?['name'] as String? ?? '';
    url.text = person?['url'] as String? ?? '';
    notes.text = person?['notes'] as String? ?? '';
    follow = person?['followPosts'] as bool? ?? true;
    selected = person == null
        ? {widget.category == 'ALL' ? 'PERSONAL' : widget.category}
        : (person['categories'] as List).cast<String>().toSet();
    if (person != null && kind != 'EXTERNAL') {
      chosen = {
        'id': person['memberId'] ?? person['contactId'],
        'name': person['name']
      };
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    name.dispose();
    url.dispose();
    notes.dispose();
    query.dispose();
    super.dispose();
  }

  Future<void> search({bool more = false}) async {
    final current = ++sequence;
    if (kind == 'EXTERNAL' || widget.person != null) {
      return;
    }
    try {
      List<Map<String, dynamic>> values;
      int? next;
      if (kind == 'MEMBER') {
        values = query.text.trim().length < 2
            ? []
            : await widget.api.searchAdvisorMembers(query.text);
      } else {
        final result = await widget.api.relationshipTreeContacts(
            query: query.text, afterId: more ? cursor ?? 0 : 0);
        values = (result['items'] as List)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        next = (result['nextCursor'] as num?)?.toInt();
      }
      if (mounted && current == sequence) {
        setState(() {
          matches = [if (more) ...matches, ...values];
          cursor = next;
        });
      }
    } catch (e) {
      if (mounted && current == sequence) {
        setState(() => error = '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.person == null ? 'Add advisor' : 'Edit advisor'),
          content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (error != null)
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    if (widget.person == null)
                      Wrap(spacing: 6, children: [
                        for (final value in ['MEMBER', 'CONTACT', 'EXTERNAL'])
                          ChoiceChip(
                              label: Text(value == 'MEMBER'
                                  ? 'MyAaptha member'
                                  : value == 'CONTACT'
                                      ? 'Private contact'
                                      : 'Profile card'),
                              selected: kind == value,
                              onSelected: busy
                                  ? null
                                  : (_) {
                                      setState(() {
                                        kind = value;
                                        chosen = null;
                                        query.clear();
                                        matches = [];
                                        cursor = null;
                                        sequence++;
                                      });
                                      if (value == 'CONTACT') {
                                        search();
                                      }
                                    })
                      ]),
                    if (kind == 'EXTERNAL') ...[
                      TextField(
                          controller: name,
                          maxLength: 200,
                          decoration:
                              const InputDecoration(labelText: 'Person name')),
                      TextField(
                          controller: url,
                          maxLength: 2048,
                          decoration: const InputDecoration(
                              labelText: 'Profile link (optional)',
                              hintText: 'https://...')),
                      const Text(
                          'Reference link only; external posts are not imported.')
                    ] else if (widget.person != null)
                      Text('${widget.person!['name']}')
                    else ...[
                      TextField(
                          controller: query,
                          decoration: InputDecoration(
                              labelText: kind == 'MEMBER'
                                  ? 'Find a member'
                                  : 'Find a contact'),
                          onChanged: (_) {
                            timer?.cancel();
                            sequence++;
                            timer = Timer(const Duration(milliseconds: 250),
                                () => search());
                          }),
                      if (chosen != null) Text("Selected: ${chosen!['name']}"),
                      ...matches.map((person) => CheckboxListTile(
                          title: Text('${person['name']}'),
                          value: chosen?['id'] == person['id'],
                          onChanged: busy
                              ? null
                              : (_) => setState(() => chosen = person))),
                      if (cursor != null)
                        TextButton(
                            onPressed: () => search(more: true),
                            child: const Text('More contacts'))
                    ],
                    const SizedBox(height: 12),
                    const Text('Categories'),
                    ...widget.categories.map((category) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${category['name']}'),
                        value: selected.contains(category['key']),
                        onChanged: busy
                            ? null
                            : (value) => setState(() {
                                  if (value == true) {
                                    selected.add(category['key'] as String);
                                  } else {
                                    selected.remove(category['key']);
                                  }
                                }))),
                    TextField(
                        controller: notes,
                        maxLength: 2000,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Private notes')),
                    if (kind == 'MEMBER')
                      CheckboxListTile(
                          title: const Text('Follow MyAaptha posts'),
                          value: follow,
                          onChanged: busy
                              ? null
                              : (value) =>
                                  setState(() => follow = value == true))
                  ]))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: busy ||
                        selected.isEmpty ||
                        (kind != 'EXTERNAL' && chosen == null)
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await widget.api.saveAdvisor({
                            'memberId': kind == 'MEMBER' ? chosen!['id'] : null,
                            'contactId':
                                kind == 'CONTACT' ? chosen!['id'] : null,
                            'name': name.text.trim(),
                            'url': url.text.trim().isEmpty
                                ? null
                                : url.text.trim(),
                            'notes': notes.text,
                            'categories': selected.toList(),
                            'followPosts': kind == 'MEMBER' && follow,
                            if (widget.person != null)
                              'version': widget.person!['version']
                          }, id: (widget.person?['id'] as num?)?.toInt());
                          if (context.mounted) {
                            Navigator.pop(context, true);
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
                child: Text(busy ? 'Saving...' : 'Save advisor'))
          ]);
}
