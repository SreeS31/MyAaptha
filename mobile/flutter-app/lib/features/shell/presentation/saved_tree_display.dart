import 'package:flutter/material.dart';
import '../../../core/network/myaaptha_api.dart';
import 'reviewed_tree_canvas.dart';

class SavedTreeDisplay extends StatefulWidget {
  const SavedTreeDisplay(
      {super.key,
      required this.api,
      required this.cards,
      required this.busy,
      required this.onEdit,
      required this.onDelete});
  final MyAapthaApi api;
  final List<Map<String, dynamic>> cards;
  final bool busy;
  final void Function(Map<String, dynamic>, String?) onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  @override
  State<SavedTreeDisplay> createState() => _SavedTreeDisplayState();
}

class _SavedTreeDisplayState extends State<SavedTreeDisplay> {
  int? chosen;
  int request = 0;
  String? selected, error;
  Map<String, dynamic>? tree;
  bool loading = false;
  Map<String, dynamic> get card => widget.cards
      .firstWhere((c) => c['id'] == chosen, orElse: () => widget.cards.first);
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant SavedTreeDisplay old) {
    super.didUpdateWidget(old);
    if (!identical(old.cards, widget.cards)) load();
  }

  Future<void> load() async {
    final generation = ++request;
    final id = card['id'];
    setState(() {
      loading = true;
      error = null;
      tree = null;
      selected = null;
    });
    try {
      final value =
          await widget.api.reviewedRelationshipTree('$id', saved: true);
      if (mounted && generation == request) setState(() => tree = value);
    } catch (e) {
      if (mounted && generation == request) setState(() => error = '$e');
    } finally {
      if (mounted && generation == request) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodes = (tree?['nodes'] as List? ?? [])
        .map((n) => Map<String, dynamic>.from(n as Map))
        .toList();
    final matches = nodes.where((n) => n['key'] == selected);
    final person = matches.isEmpty ? null : matches.first;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tree?['name'] ?? card['name']}',
                  style: Theme.of(context).textTheme.titleLarge),
              Text('${tree == null ? card['count'] : nodes.length} people'),
              DropdownButtonFormField<int>(
                  key: ValueKey(card['id']),
                  isExpanded: true,
                  initialValue: (card['id'] as num).toInt(),
                  decoration:
                      const InputDecoration(labelText: 'Choose a saved tree'),
                  items: widget.cards
                      .map((c) => DropdownMenuItem(
                          value: (c['id'] as num).toInt(),
                          child: Text('${c['name']} (${c['count']})',
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: widget.busy
                      ? null
                      : (id) {
                          chosen = id;
                          load();
                        }),
              Wrap(spacing: 8, children: [
                TextButton(
                    onPressed: widget.busy || loading || tree == null
                        ? null
                        : () => widget.onEdit(card, null),
                    child: const Text('Edit tree')),
                TextButton(
                    onPressed: widget.busy || loading
                        ? null
                        : () => widget.onDelete(card),
                    child: const Text('Delete tree'))
              ]),
              if (loading) const LinearProgressIndicator(),
              if (error != null) ...[
                Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                TextButton(onPressed: load, child: const Text('Retry'))
              ],
              if (tree != null)
                ReviewedTreeCanvas(
                    key: ValueKey('${tree!['id']}:${tree!['version']}'),
                    nodes: nodes,
                    initiallyExpanded: false,
                    connectRoots: true,
                    selected: selected,
                    onSelect: (n) =>
                        setState(() => selected = n['key'] as String)),
              if (person != null)
                Wrap(spacing: 8, children: [
                  Text('${person['name']} · ${person['relation']}'),
                  TextButton(
                      onPressed: widget.busy
                          ? null
                          : () => widget.onEdit(card, selected),
                      child: const Text('Edit person'))
                ])
            ])));
  }
}
