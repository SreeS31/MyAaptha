import 'dart:async';
import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class ChatDiscoveryScreen extends StatefulWidget {
  const ChatDiscoveryScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<ChatDiscoveryScreen> createState() => _ChatDiscoveryScreenState();
}

class _ChatDiscoveryScreenState extends State<ChatDiscoveryScreen> {
  final query = TextEditingController(), name = TextEditingController();
  List<ChatTarget> targets = [], people = [];
  List<Map<String, dynamic>> hits = [];
  final selected = <int>{};
  Timer? debounce;
  int version = 0;
  bool loading = true, searching = false, group = false, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    query.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final choices = await widget.api.forwardTargets();
      final relations = await widget.api.relationships();
      final members = <int, ChatTarget>{
        for (final relation in relations.where((r) => r.person.canConnect))
          relation.person.id: ChatTarget(
              type: 'DIRECT',
              id: relation.person.id,
              name: relation.person.displayName)
      };
      if (mounted) {
        setState(() {
          targets = choices;
          people = members.values.toList();
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  void search(String value) {
    debounce?.cancel();
    final current = ++version;
    setState(() {
      hits = [];
      searching = !group && value.trim().length >= 2;
      error = null;
    });
    if (!searching) return;
    debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final result = await widget.api.searchAllChats(value.trim());
        if (mounted && current == version) {
          setState(() {
            hits = result;
            searching = false;
          });
        }
      } catch (e) {
        if (mounted && current == version) {
          setState(() {
            searching = false;
            error = '$e';
          });
        }
      }
    });
  }

  Future<void> createGroup() async {
    if (name.text.trim().isEmpty || selected.isEmpty) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final created =
          await widget.api.createChatGroup(name.text.trim(), selected.toList());
      if (mounted) {
        Navigator.pop(context,
            ChatTarget(type: 'CIRCLE', id: created.id, name: created.name));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = (group ? people : targets)
        .where((target) =>
            target.name.toLowerCase().contains(query.text.trim().toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(group ? 'New group' : 'Find a conversation')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SwitchListTile(
            title: const Text('Create a group'),
            value: group,
            onChanged: saving
                ? null
                : (value) {
                    setState(() => group = value);
                    search(query.text);
                  }),
        if (group)
          TextField(
              controller: name,
              maxLength: 100,
              enabled: !saving,
              decoration: const InputDecoration(labelText: 'Group name'),
              onChanged: (_) => setState(() {})),
        TextField(
            controller: query,
            maxLength: 100,
            enabled: !saving,
            decoration: InputDecoration(
                labelText: group
                    ? 'Find members'
                    : 'Search people, circles & messages',
                prefixIcon: const Icon(Icons.search)),
            onChanged: search),
        if (loading || searching || saving) const LinearProgressIndicator(),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (group) Text('${selected.length} / 100 members selected'),
        for (final target in choices)
          if (group)
            CheckboxListTile(
                title: Text(target.name),
                value: selected.contains(target.id),
                onChanged: saving ||
                        (!selected.contains(target.id) &&
                            selected.length >= 100)
                    ? null
                    : (value) => setState(() {
                          if (value == true) {
                            selected.add(target.id);
                          } else {
                            selected.remove(target.id);
                          }
                        }))
          else
            ListTile(
                leading:
                    Icon(target.type == 'CIRCLE' ? Icons.groups : Icons.person),
                title: Text(target.name),
                subtitle: Text(target.type == 'CIRCLE' ? 'Circle' : 'Person'),
                onTap: () => Navigator.pop(context, target)),
        if (group)
          FilledButton(
              onPressed: saving || name.text.trim().isEmpty || selected.isEmpty
                  ? null
                  : createGroup,
              child: const Text('Create group')),
        if (!group && query.text.trim().length >= 2) ...[
          Text('Messages', style: Theme.of(context).textTheme.titleLarge),
          for (final hit in hits)
            ListTile(
                title: Text(hit['name'] as String? ?? 'Conversation'),
                subtitle: Text(hit['text'] as String? ?? ''),
                onTap: () => Navigator.pop(
                    context,
                    ChatTarget(
                        type: hit['type'] as String,
                        id: (hit['conversationId'] as num).toInt(),
                        name: hit['name'] as String? ?? 'Conversation'))),
          if (!searching && hits.isEmpty && error == null)
            const Text('No matching messages.'),
          if (hits.length == 50)
            const Text(
                'Showing the latest 50 matches. Refine your search for more.'),
        ],
      ]),
    );
  }
}
