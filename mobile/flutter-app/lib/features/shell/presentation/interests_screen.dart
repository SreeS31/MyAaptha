import 'package:myaaptha_mobile/core/config/display_copy.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'interest_catalog.dart';

Future<List<String>?> showInterestPicker(
    BuildContext context, List<String> current) async {
  final selected = current.toSet();
  String query = '', category = '';
  return showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, update) {
            final options = (category.isEmpty
                    ? (<String>{...allInterests, ...selected}.toList()..sort())
                    : interestCategories[category]!)
                .where((v) => v.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return AlertDialog(
                scrollable: true,
                title: const Text('Choose interests'),
                content: SizedBox(
                    width: 600,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          maxLength: 120,
                          decoration: const InputDecoration(
                              labelText: 'Find a hobby or interest',
                              counterText: ''),
                          onChanged: (v) => update(() => query = v)),
                      DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('All categories')),
                            ...interestCategories.keys.map((v) =>
                                DropdownMenuItem(
                                    value: v,
                                    child: Text(v,
                                        overflow: TextOverflow.ellipsis)))
                          ],
                          onChanged: (v) => update(() => category = v ?? '')),
                      Text('${selected.length} selected'),
                      SizedBox(
                          height: math.min(
                              240, MediaQuery.sizeOf(context).height * .3),
                          child: ListView.builder(
                              itemCount: options.length,
                              itemBuilder: (context, i) => CheckboxListTile(
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(options[i]),
                                  value: selected.contains(options[i]),
                                  onChanged: (v) => update(() => v == true
                                      ? selected.add(options[i])
                                      : selected.remove(options[i]))))),
                      if (query.trim().isNotEmpty &&
                          !query.contains(',') &&
                          !selected.any((v) =>
                              v.toLowerCase() == query.trim().toLowerCase()) &&
                          !allInterests.any((v) =>
                              v.toLowerCase() == query.trim().toLowerCase()))
                        TextButton(
                            onPressed: () =>
                                update(() => selected.add(query.trim())),
                            child: Text('Add "${query.trim()}"')),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, selected.toList()),
                      child: const Text('Save interests'))
                ]);
          }));
}

Future<Map<String, dynamic>?> interestGroupEditor(BuildContext context,
        {Map<String, dynamic>? group}) =>
    showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => _InterestGroupEditor(group: group));

class _InterestGroupEditor extends StatefulWidget {
  const _InterestGroupEditor({this.group});
  final Map<String, dynamic>? group;
  @override
  State<_InterestGroupEditor> createState() => _InterestGroupEditorState();
}

class _InterestGroupEditorState extends State<_InterestGroupEditor> {
  final key = GlobalKey<FormState>();
  late final name =
      TextEditingController(text: widget.group?['name'] as String? ?? '');
  late final topic =
      TextEditingController(text: widget.group?['topic'] as String? ?? '');
  late final area =
      TextEditingController(text: widget.group?['area'] as String? ?? '');
  late final description = TextEditingController(
      text: widget.group?['description'] as String? ?? '');
  @override
  void dispose() {
    name.dispose();
    topic.dispose();
    area.dispose();
    description.dispose();
    super.dispose();
  }

  String? requiredValue(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;
  @override
  Widget build(BuildContext context) => AlertDialog(
          scrollable: true,
          title: Text(widget.group == null ? 'Create a group' : 'Edit group'),
          content: SizedBox(
              width: 600,
              child: Form(
                  key: key,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(
                        controller: name,
                        maxLength: 160,
                        decoration:
                            const InputDecoration(labelText: 'Group name'),
                        validator: requiredValue),
                    Autocomplete<String>(
                        initialValue: TextEditingValue(text: topic.text),
                        optionsBuilder: (value) => allInterests.where((v) =>
                            v.toLowerCase().contains(value.text.toLowerCase())),
                        onSelected: (value) => topic.text = value,
                        fieldViewBuilder:
                            (context, controller, focus, onSubmit) =>
                                TextFormField(
                                    controller: controller,
                                    focusNode: focus,
                                    maxLength: 120,
                                    decoration: const InputDecoration(
                                        labelText: 'Group interest'),
                                    onChanged: (value) => topic.text = value,
                                    validator: requiredValue)),
                    TextFormField(
                        controller: area,
                        maxLength: 200,
                        decoration: const InputDecoration(
                            labelText: 'Group area',
                            hintText: 'Hyderabad, India, worldwide'),
                        validator: requiredValue),
                    TextFormField(
                        controller: description,
                        maxLength: 4000,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'About this group'),
                        validator: requiredValue),
                  ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (key.currentState!.validate()) {
                    Navigator.pop(context, {
                      'name': name.text.trim(),
                      'topic': topic.text.trim(),
                      'area': area.text.trim(),
                      'description': description.text.trim()
                    });
                  }
                },
                child:
                    Text(widget.group == null ? 'Create group' : 'Save group'))
          ]);
}

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  final search = TextEditingController(), area = TextEditingController();
  Timer? debounce;
  int version = 0, page = 0;
  bool mine = false, hasNext = false, loading = true, busy = false;
  String topic = '';
  String? error;
  List<String> interests = [];
  List<Map<String, dynamic>> groups = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    area.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final request = ++version;
    setState(() => loading = true);
    try {
      final values = await Future.wait([
        widget.api.interests(),
        widget.api.interestGroups(
            query: search.text,
            area: area.text,
            topic: topic,
            mine: mine,
            page: page)
      ]);
      if (!mounted || request != version) return;
      final result = values[1] as Map<String, dynamic>;
      setState(() {
        interests = (values[0] as List).cast<String>();
        groups = (result['items'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        hasNext = result['hasNext'] == true;
        error = null;
      });
    } catch (e) {
      if (mounted && request == version) setState(() => error = '$e');
    } finally {
      if (mounted && request == version) setState(() => loading = false);
    }
  }

  void filter() {
    page = 0;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), load);
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

  Future<void> open(Map<String, dynamic> group) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                InterestGroupScreen(api: widget.api, group: group)));
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
              child: Text('Interests',
                  style: Theme.of(context).textTheme.headlineLarge)),
          IconButton(
              tooltip: 'Refresh interests',
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh))
        ]),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text('My interests',
                                style: Theme.of(context).textTheme.titleLarge)),
                        TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    final chosen = await showInterestPicker(
                                        context, interests);
                                    if (chosen != null && mounted) {
                                      await action(() async {
                                        final saved = await widget.api
                                            .saveInterests(chosen);
                                        if (mounted) {
                                          setState(() => interests = saved);
                                        }
                                      });
                                    }
                                  },
                            child: Text(interests.isEmpty
                                ? 'Add interests'
                                : 'Edit interests'))
                      ]),
                      if (interests.isEmpty)
                        const Text(
                            DisplayCopy.noInterests),
                      Wrap(
                          spacing: 6,
                          children: interests
                              .map((v) => ActionChip(
                                  label: Text(v),
                                  onPressed: () {
                                    setState(() => topic = v);
                                    filter();
                                  }))
                              .toList())
                    ]))),
        const SizedBox(height: 16),
        Text('Groups for your interests',
            style: Theme.of(context).textTheme.titleLarge),
        Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final value = await interestGroupEditor(context);
                        if (value != null && mounted) {
                          await action(() async {
                            final group =
                                await widget.api.createInterestGroup(value);
                            if (mounted) await open(group);
                          });
                        }
                      },
                icon: const Icon(Icons.add),
                label: const Text('Create a group'))),
        TextField(
            controller: search,
            maxLength: 200,
            decoration: const InputDecoration(
                labelText: 'Search groups', counterText: ''),
            onChanged: (_) => filter()),
        TextField(
            controller: area,
            maxLength: 200,
            decoration:
                const InputDecoration(labelText: 'Area', counterText: ''),
            onChanged: (_) => filter()),
        DropdownButtonFormField<String>(
            key: ValueKey(topic),
            initialValue: topic,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Interest'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All interests')),
              ...({...allInterests, ...interests}.toList()..sort()).map((v) =>
                  DropdownMenuItem(
                      value: v,
                      child: Text(v, overflow: TextOverflow.ellipsis)))
            ],
            onChanged: (v) {
              setState(() => topic = v ?? '');
              filter();
            }),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('My groups & requests'),
            value: mine,
            onChanged: (v) {
              setState(() => mine = v ?? false);
              filter();
            }),
        if (loading)
          const LinearProgressIndicator()
        else if (groups.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child:
                  Text(DisplayCopy.noGroups)),
        ...groups.map((g) => Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g['name'] as String,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('${g['topic']} - ${g['area']}'),
                      Text(
                          '${g['memberCount']} members${g['admin'] == true ? ' - You are admin' : ''}'),
                      Text(g['description'] as String),
                      if (g['membership'] == 'REQUESTED')
                        const Text('Awaiting admin approval'),
                      TextButton(
                          onPressed: busy ? null : () => open(g),
                          child: Text(g['membership'] == 'ACTIVE'
                              ? 'Open group'
                              : 'View group'))
                    ])))),
        Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                  onPressed: loading || page == 0
                      ? null
                      : () {
                          page--;
                          load();
                        },
                  child: const Text('Previous groups')),
              Text('Page ${page + 1}'),
              TextButton(
                  onPressed: loading || !hasNext
                      ? null
                      : () {
                          page++;
                          load();
                        },
                  child: const Text('More groups'))
            ])
      ]));
}

class InterestGroupScreen extends StatefulWidget {
  const InterestGroupScreen(
      {super.key, required this.api, required this.group});
  final MyAapthaApi api;
  final Map<String, dynamic> group;
  @override
  State<InterestGroupScreen> createState() => _InterestGroupScreenState();
}

class _InterestGroupScreenState extends State<InterestGroupScreen> {
  late Map<String, dynamic> group = Map.from(widget.group);
  final message = TextEditingController();
  List<Map<String, dynamic>> requests = [], messages = [];
  int requestPage = 0, messagePage = 0;
  bool requestNext = false, messageNext = false, busy = false, loading = true;
  String? error;
  String get id => (group['id'] as String);
  bool get admin => group['admin'] == true;
  bool get active => group['membership'] == 'ACTIVE';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final latest = await widget.api.interestGroup(id);
      final pending = latest['admin'] == true
          ? await widget.api.interestRequests(id, page: requestPage)
          : {'items': [], 'hasNext': false};
      final discussion = latest['membership'] == 'ACTIVE'
          ? await widget.api.interestMessages(id, page: messagePage)
          : {'items': [], 'hasNext': false};
      if (!mounted) return;
      setState(() {
        group = latest;
        requests = (pending['items'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        messages = (discussion['items'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        requestNext = pending['hasNext'] == true;
        messageNext = discussion['hasNext'] == true;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> action(Future<void> Function() task) async {
    setState(() => busy = true);
    try {
      await task();
      if (mounted) await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(group['name'] as String), actions: [
        IconButton(
            tooltip: 'Refresh group',
            onPressed: busy || loading ? null : load,
            icon: const Icon(Icons.refresh))
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${group['topic']} - ${group['area']}'),
        Text(group['description'] as String),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (loading) const LinearProgressIndicator(),
        if (admin)
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: busy || loading
                      ? null
                      : () async {
                          final value =
                              await interestGroupEditor(context, group: group);
                          if (value != null && mounted) {
                            await action(() async {
                              await widget.api.editInterestGroup(id, value);
                            });
                          }
                        },
                  child: const Text('Edit group')))
        else if (active || group['membership'] == 'REQUESTED')
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: busy || loading
                      ? null
                      : () => action(() async {
                            await widget.api.leaveInterestGroup(id);
                          }),
                  child: Text(active ? 'Leave group' : 'Cancel join request')))
        else
          Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                  onPressed: busy || loading
                      ? null
                      : () => action(() async {
                            await widget.api.joinInterestGroup(id);
                          }),
                  child: const Text('Request to join'))),
        if (admin) ...[
          Text('Join requests', style: Theme.of(context).textTheme.titleLarge),
          if (requests.isEmpty && !loading) const Text(DisplayCopy.noRequests),
          ...requests.map((r) => Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['name'] as String),
                        Wrap(spacing: 8, children: [
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => action(() => widget.api
                                      .decideInterestRequest(
                                          id, r['userId'] as int, true)),
                              child: const Text('Approve')),
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => action(() => widget.api
                                      .decideInterestRequest(
                                          id, r['userId'] as int, false)),
                              child: const Text('Decline'))
                        ])
                      ])))),
          Wrap(children: [
            TextButton(
                onPressed: requestPage == 0 || busy
                    ? null
                    : () {
                        requestPage--;
                        load();
                      },
                child: const Text('Previous requests')),
            TextButton(
                onPressed: !requestNext || busy
                    ? null
                    : () {
                        requestPage++;
                        load();
                      },
                child: const Text('More requests'))
          ])
        ],
        Text('Group discussion', style: Theme.of(context).textTheme.titleLarge),
        if (active) ...[
          TextField(
              controller: message,
              maxLength: 10000,
              minLines: 2,
              maxLines: 5,
              decoration:
                  const InputDecoration(labelText: 'Message to the group')),
          Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                  onPressed: busy || loading
                      ? null
                      : () => action(() async {
                            if (message.text.trim().isEmpty) return;
                            await widget.api
                                .postInterestMessage(id, message.text);
                            message.clear();
                            messagePage = 0;
                          }),
                  child: const Text('Post message'))),
          if (messages.isEmpty && !loading) const Text(DisplayCopy.noMessages),
          ...messages.map((m) => Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['author'] as String,
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(m['body'] as String),
                        if (admin || m['mine'] == true)
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => action(() => widget.api
                                      .deleteInterestMessage(
                                          id, m['id'] as String)),
                              child: const Text('Delete message'))
                      ])))),
          Wrap(children: [
            TextButton(
                onPressed: messagePage == 0 || busy
                    ? null
                    : () {
                        messagePage--;
                        load();
                      },
                child: const Text('Newer messages')),
            TextButton(
                onPressed: !messageNext || busy
                    ? null
                    : () {
                        messagePage++;
                        load();
                      },
                child: const Text('Older messages'))
          ])
        ] else
          Text(group['membership'] == 'REQUESTED'
              ? 'Your request is awaiting admin approval.'
              : 'Only approved members can read or post discussions.'),
      ]));
}
