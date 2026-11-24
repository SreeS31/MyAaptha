import 'package:flutter/material.dart';
import '../../../core/network/myaaptha_api.dart';

class ProjectInputsScreen extends StatefulWidget {
  const ProjectInputsScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<ProjectInputsScreen> createState() => _ProjectInputsState();
}

class _ProjectInputsState extends State<ProjectInputsScreen> {
  List<Map<String, dynamic>> tasks = [];
  final controllers = <String, TextEditingController>{};
  bool busy = false;
  String? error, notice;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final data = await widget.api.projectInputs();
      if (mounted) setState(() => tasks = data);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void edit(Map<String, dynamic> task, String key, String value) {
    setState(() {
      (task['values'] as Map)[key] = value;
      task['ready'] = false;
      notice = null;
    });
  }

  Future<void> save(Map<String, dynamic> task, bool ready) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final saved = await widget.api.saveProjectInputs(
          task['definition']['key'] as String,
          task['values'] as Map,
          ready,
          task['version'] as int);
      if (mounted) {
        setState(() {
          tasks = tasks
              .map((t) => t['definition']['key'] == saved['definition']['key']
                  ? saved
                  : t)
              .toList();
          notice = ready
              ? 'Saved for review. Tell me when ready for the next implementation pass.'
              : 'Draft saved.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'Project setup and decisions. Public IDs and Secret Manager references only. Saving does not activate integrations or deploy code.'),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (notice != null) Text(notice!),
        ...tasks.map((task) {
          final definition = task['definition'] as Map;
          return Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${definition['title']}',
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(task['ready'] == true
                            ? 'Ready for review'
                            : task['version'] == 0
                                ? 'Needs input'
                                : 'Draft saved'),
                        Text('${definition['pendingWork']}'),
                        ...(definition['fields'] as List).map((raw) {
                          final field = raw as Map;
                          final key = field['key'] as String;
                          final value =
                              (task['values'] as Map)[key] as String? ?? '';
                          return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: field['kind'] == 'choice'
                                  ? DropdownButtonFormField<String>(
                                      key: ValueKey(
                                          '${definition['key']}-$key-$value'),
                                      isExpanded: true,
                                      initialValue:
                                          value.isEmpty ? null : value,
                                      decoration: InputDecoration(
                                          labelText: '${field['label']}'),
                                      items: (field['options'] as List)
                                          .map((o) => DropdownMenuItem(
                                              value: '$o',
                                              child: Text('$o',
                                                  overflow:
                                                      TextOverflow.ellipsis)))
                                          .toList(),
                                      onChanged: busy
                                          ? null
                                          : (v) => edit(task, key, v ?? ''))
                                  : TextField(
                                      controller: controllers.putIfAbsent(
                                          '${definition['key']}-$key',
                                          () => TextEditingController(
                                              text: value)),
                                      enabled: !busy,
                                      maxLength: 300,
                                      decoration: InputDecoration(
                                          labelText: '${field['label']}',
                                          hintText: field['kind'] == 'secret-reference'
                                              ? 'projects/PROJECT/secrets/NAME/versions/latest'
                                              : null),
                                      onChanged: (v) => edit(task, key, v)));
                        }),
                        Wrap(spacing: 8, children: [
                          TextButton(
                              onPressed: busy ? null : () => save(task, false),
                              child: const Text('Save draft')),
                          FilledButton(
                              onPressed: busy ? null : () => save(task, true),
                              child: const Text('Ready for review'))
                        ])
                      ])));
        })
      ]);
}
