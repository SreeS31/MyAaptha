import 'dart:math' as math;
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
  final open = <int>{};
  final transform = TransformationController();
  Size? lastViewport;
  double? lastSize;
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  void toggle(int id) => setState(() {
        if (!open.remove(id)) open.add(id);
      });
  @override
  Widget build(BuildContext context) {
    final positions = <Offset>[];
    int used = 0, ring = 0;
    double radius = 245;
    while (used < widget.cards.length) {
      radius = 245 + ring * 190.0;
      final count = math.min(
          widget.cards.length - used, (2 * math.pi * radius / 190).floor());
      for (int i = 0; i < count; i++) {
        final angle = -math.pi / 2 + 2 * math.pi * i / count;
        positions
            .add(Offset(math.cos(angle) * radius, math.sin(angle) * radius));
      }
      used += count;
      ring++;
    }
    final size = 2 * (radius + 110), center = Offset(size / 2, size / 2);
    return Column(children: [
      SizedBox(
          height: 520,
          child: LayoutBuilder(builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, 520);
            if (lastViewport != viewport || lastSize != size) {
              lastViewport = viewport;
              lastSize = size;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final scale = math.min(1.0,
                    math.min(viewport.width / size, viewport.height / size));
                transform.value = Matrix4.identity()
                  ..translateByDouble((viewport.width - size * scale) / 2,
                      (viewport.height - size * scale) / 2, 0, 1)
                  ..scaleByDouble(scale, scale, scale, 1);
              });
            }
            return ClipRect(
                child: InteractiveViewer(
                    transformationController: transform,
                    constrained: false,
                    minScale: .05,
                    maxScale: 2,
                    child: SizedBox(
                        width: size,
                        height: size,
                        child: Stack(children: [
                          Positioned.fill(
                              child: CustomPaint(
                                  painter:
                                      _CircleConnections(center, positions))),
                          Positioned(
                              left: center.dx - 43,
                              top: center.dy - 43,
                              width: 86,
                              height: 86,
                              child: const CircleAvatar(child: Text('You'))),
                          for (int i = 0; i < widget.cards.length; i++)
                            Positioned(
                                left: center.dx + positions[i].dx - 80,
                                top: center.dy + positions[i].dy - 36,
                                width: 160,
                                height: 72,
                                child: Semantics(
                                    button: true,
                                    expanded:
                                        open.contains(widget.cards[i]['id']),
                                    child: OutlinedButton(
                                        onPressed: widget.busy
                                            ? null
                                            : () => toggle(
                                                (widget.cards[i]['id'] as num)
                                                    .toInt()),
                                        style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            backgroundColor:
                                                open.contains(widget.cards[i]['id'])
                                                    ? const Color(0xffe6f2ef)
                                                    : Colors.white),
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                  widget.cards[i]['name']
                                                      as String,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center),
                                              Text(
                                                  '${widget.cards[i]['count']} people ${open.contains(widget.cards[i]['id']) ? '-' : '+'}',
                                                  style: const TextStyle(
                                                      fontSize: 12))
                                            ]))))
                        ]))));
          })),
      for (final card in widget.cards)
        if (open.contains(card['id']))
          _ExpandedSavedTree(
              key: ValueKey(card['id']),
              api: widget.api,
              card: card,
              busy: widget.busy,
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
              onCollapse: () => toggle((card['id'] as num).toInt()))
    ]);
  }
}

class _CircleConnections extends CustomPainter {
  _CircleConnections(this.center, this.positions);
  final Offset center;
  final List<Offset> positions;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff94b7b8)
      ..strokeWidth = 2;
    for (final position in positions) {
      canvas.drawLine(center, center + position, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircleConnections old) =>
      old.center != center || old.positions != positions;
}

class _ExpandedSavedTree extends StatefulWidget {
  const _ExpandedSavedTree(
      {super.key,
      required this.api,
      required this.card,
      required this.onCollapse,
      required this.busy,
      required this.onEdit,
      required this.onDelete});
  final MyAapthaApi api;
  final Map<String, dynamic> card;
  final VoidCallback onCollapse;
  final bool busy;
  final void Function(Map<String, dynamic>, String?) onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  @override
  State<_ExpandedSavedTree> createState() => __ExpandedSavedTreeState();
}

class __ExpandedSavedTreeState extends State<_ExpandedSavedTree> {
  int request = 0;
  String? selected, error;
  Map<String, dynamic>? tree;
  bool loading = false;
  Map<String, dynamic> get card => widget.card;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant _ExpandedSavedTree old) {
    super.didUpdateWidget(old);
    if (old.card['id'] != widget.card['id'] ||
        old.card['version'] != widget.card['version']) {
      load();
    }
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
              Wrap(spacing: 8, children: [
                TextButton(
                    onPressed: widget.onCollapse,
                    child: const Text('Collapse tree')),
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
                    rootInitiallyOpen: true,
                    rootName: card['name'] as String,
                    selected: selected,
                    onSelect: (n) =>
                        setState(() => selected = n['key'] as String)),
              if (person != null)
                Wrap(spacing: 8, children: [
                  TextButton(
                      onPressed: widget.onCollapse,
                      child: const Text('Collapse tree')),
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
