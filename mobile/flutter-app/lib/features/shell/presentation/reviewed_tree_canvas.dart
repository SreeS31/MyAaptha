import 'package:flutter/material.dart';

class ReviewedTreeCanvas extends StatefulWidget {
  const ReviewedTreeCanvas(
      {super.key,
      required this.nodes,
      required this.selected,
      required this.onSelect,
      this.initiallyExpanded = false,
      this.connectRoots = false});
  final bool connectRoots;
  final bool initiallyExpanded;
  final List<Map<String, dynamic>> nodes;
  final String? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;
  @override
  State<ReviewedTreeCanvas> createState() => _ReviewedTreeCanvasState();
}

class _ReviewedTreeCanvasState extends State<ReviewedTreeCanvas> {
  String layout = 'Compact';
  late bool rootOpen;
  final expanded = <String>{};
  int limit = 80;
  final transform = TransformationController();
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    rootOpen = !widget.connectRoots || widget.initiallyExpanded;
    if (widget.initiallyExpanded) {
      expanded.addAll(widget.nodes.map((n) => n['key'] as String));
    }
    revealSelection();
  }

  @override
  void didUpdateWidget(covariant ReviewedTreeCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    revealSelection();
  }

  void revealSelection() {
    final byKey = {for (final node in widget.nodes) node['key']: node};
    var node = byKey[widget.selected];
    if (node != null) rootOpen = true;
    final seen = <String>{};
    while (
        node?['parentKey'] != null && seen.add(node!['parentKey'] as String)) {
      expanded.add(node['parentKey'] as String);
      node = byKey[node['parentKey']];
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <String?, List<Map<String, dynamic>>>{};
    for (final n in widget.nodes) {
      children.putIfAbsent(n['parentKey'] as String?, () => []).add(n);
    }
    final byKey = {for (final n in widget.nodes) n['key']: n};
    final priority = <String>{};
    var focus = byKey[widget.selected];
    while (focus != null && priority.add(focus['key'] as String)) {
      focus = byKey[focus['parentKey']];
    }
    List<Map<String, dynamic>> ordered(List<Map<String, dynamic>> list) =>
        priority.isEmpty
            ? list
            : [
                ...list.where((n) => priority.contains(n['key'])),
                ...list.where((n) => !priority.contains(n['key']))
              ];
    final entries = <_Entry>[];
    final seen = <String>{};
    var leaf = 0;
    var truncated = false;
    double visit(Map<String, dynamic> node, int depth, String? parent) {
      if (!seen.add(node['key'] as String)) return -1;
      if (entries.length >= limit) {
        truncated = true;
        return -1;
      }
      final entry = _Entry(node, depth, parent);
      entries.add(entry);
      final positions = <double>[];
      if (expanded.contains(node['key'])) {
        for (final child
            in ordered(children[node['key']] ?? <Map<String, dynamic>>[])) {
          final p = visit(child, depth + 1, node['key'] as String);
          if (p >= 0) positions.add(p);
        }
      }
      final pos = positions.isEmpty
          ? (leaf++).toDouble()
          : (positions.first + positions.last) / 2;
      entry.offset = Offset(pos * 210 + 20, depth * 125 + 20);
      return pos;
    }

    for (final root in ordered(rootOpen
        ? (children[null] ?? <Map<String, dynamic>>[])
        : <Map<String, dynamic>>[])) {
      visit(root, 0, null);
    }
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (layout == 'Right-growing') {
        entry.offset =
            Offset(entry.depth * 245 + 20, entry.offset.dx / 210 * 95);
      } else if (layout == 'Compact') {
        entry.offset = Offset(entry.depth * 26 + 20, i * 76 + 20);
      }
    }
    final width = entries.fold<double>(
        320, (v, e) => v > e.offset.dx + 200 ? v : e.offset.dx + 200);
    final height = entries.fold<double>(
        180, (v, e) => v > e.offset.dy + 100 ? v : e.offset.dy + 100);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          spacing: 6,
          children: ['Modern', 'Heritage', 'Compact', 'Right-growing']
              .map((mode) => ChoiceChip(
                  label: Text(mode),
                  selected: layout == mode,
                  onSelected: (_) => setState(() => layout = mode)))
              .toList()),
      Wrap(spacing: 8, children: [
        TextButton(
            onPressed: () => setState(() {
                  rootOpen = true;
                  expanded.addAll(widget.nodes.map((n) => n['key'] as String));
                }),
            child: const Text('Expand all')),
        TextButton(
            onPressed: () => setState(() {
                  expanded.clear();
                  rootOpen = !widget.connectRoots;
                  layout = 'Compact';
                  limit = 80;
                  transform.value = Matrix4.identity();
                }),
            child: const Text('Reset view'))
      ]),
      const Wrap(spacing: 10, children: [
        Text('● Men', style: TextStyle(color: Color(0xff326bc4))),
        Text('● Women', style: TextStyle(color: Color(0xffbe3273))),
        Text('● Other / unspecified'),
        Text('● Has branches'),
        Text('○ End node')
      ]),
      TextButton.icon(
          onPressed: () => setState(() => rootOpen = !rootOpen),
          icon: Icon(rootOpen ? Icons.remove_circle : Icons.add_circle),
          label: Text(rootOpen ? 'You: Collapse tree' : 'You: Expand tree')),
      if (rootOpen)
        SizedBox(
            height: 350,
            child: ClipRect(
                child: InteractiveViewer(
                    constrained: false,
                    transformationController: transform,
                    minScale: .3,
                    maxScale: 2,
                    child: SizedBox(
                        width: width,
                        height: height,
                        child: Stack(children: [
                          Positioned.fill(
                              child: CustomPaint(
                                  painter: _Edges(
                                      entries, layout, widget.connectRoots))),
                          ...entries.map((entry) {
                            final node = entry.node;
                            final hasChildren =
                                (children[node['key']] ?? []).isNotEmpty;
                            final color = node['gender'] == 'MALE'
                                ? const Color(0xff326bc4)
                                : node['gender'] == 'FEMALE'
                                    ? const Color(0xffbe3273)
                                    : const Color(0xff64748b);
                            return Positioned(
                                left: entry.offset.dx,
                                top: entry.offset.dy,
                                width: 180,
                                height: 64,
                                child: Container(
                                    decoration: BoxDecoration(
                                        color: layout == 'Heritage'
                                            ? const Color(0xfffffaf0)
                                            : Colors.white,
                                        border: Border.all(
                                            color:
                                                widget.selected == node['key']
                                                    ? Colors.teal
                                                    : color,
                                            width: 2),
                                        borderRadius: BorderRadius.circular(
                                            layout == 'Heritage' ? 3 : 16)),
                                    child: Row(children: [
                                      Expanded(
                                          child: TextButton(
                                              onPressed: () =>
                                                  widget.onSelect(node),
                                              child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text('${node['name']}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis),
                                                    Text('${node['relation']}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontSize: 11))
                                                  ]))),
                                      if (hasChildren)
                                        IconButton(
                                            tooltip:
                                                '${expanded.contains(node['key']) ? 'Collapse' : 'Expand'} ${node['name']}',
                                            onPressed: () => setState(() {
                                                  final key =
                                                      node['key'] as String;
                                                  if (!expanded.remove(key)) {
                                                    expanded.add(key);
                                                  }
                                                }),
                                            icon: Icon(
                                                expanded.contains(node['key'])
                                                    ? Icons.remove_circle
                                                    : Icons.add_circle,
                                                color: color))
                                      else
                                        Semantics(
                                            label: '${node['name']}: end node',
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Icon(
                                                    Icons.circle_outlined,
                                                    color: color,
                                                    size: 24)))
                                    ])));
                          })
                        ]))))),
      if (truncated)
        TextButton(
            onPressed: () => setState(() {
                  limit += 100;
                }),
            child: Text(
                'Show more people (${entries.length} of ${widget.nodes.length})'))
    ]);
  }
}

class _Entry {
  _Entry(this.node, this.depth, this.parent);
  final Map<String, dynamic> node;
  final int depth;
  final String? parent;
  Offset offset = Offset.zero;
}

class _Edges extends CustomPainter {
  _Edges(this.entries, this.layout, this.connectRoots);
  final bool connectRoots;
  final List<_Entry> entries;
  final String layout;
  @override
  void paint(Canvas canvas, Size size) {
    final byKey = {for (final e in entries) e.node['key']: e};
    final paint = Paint()
      ..color = const Color(0xff94a3b8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final entry in entries) {
      final parent = byKey[entry.parent];
      if (parent == null) {
        if (connectRoots) {
          final root = Path()..moveTo(25, 0);
          if (layout == 'Right-growing' || layout == 'Compact') {
            root
              ..lineTo(8, 0)
              ..lineTo(8, entry.offset.dy + 32)
              ..lineTo(entry.offset.dx, entry.offset.dy + 32);
          } else {
            root
              ..lineTo(25, 8)
              ..lineTo(entry.offset.dx + 90, 8)
              ..lineTo(entry.offset.dx + 90, entry.offset.dy);
          }
          canvas.drawPath(root, paint);
        }
        continue;
      }
      final p = Path();
      if (layout == 'Right-growing') {
        p.moveTo(parent.offset.dx + 180, parent.offset.dy + 32);
        p.lineTo(entry.offset.dx - 20, parent.offset.dy + 32);
        p.lineTo(entry.offset.dx - 20, entry.offset.dy + 32);
        p.lineTo(entry.offset.dx, entry.offset.dy + 32);
      } else {
        p.moveTo(parent.offset.dx + 90, parent.offset.dy + 64);
        p.lineTo(parent.offset.dx + 90, entry.offset.dy - 15);
        p.lineTo(entry.offset.dx + 90, entry.offset.dy - 15);
        p.lineTo(entry.offset.dx + 90, entry.offset.dy);
      }
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Edges oldDelegate) => true;
}
