import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/models/network_models.dart';

class ChainNetworkView extends StatefulWidget {
  const ChainNetworkView(
      {super.key,
      required this.relationships,
      required this.profile,
      required this.onDetails});
  final List<Relationship> relationships;
  final UserProfileModel? profile;
  final ValueChanged<Relationship> onDetails;
  @override
  State<ChainNetworkView> createState() => _ChainNetworkViewState();
}

class _ChainNetworkViewState extends State<ChainNetworkView> {
  final expanded = <int>{-1};
  final transform = TransformationController();
  Size? previousSize;
  Size? previousViewport;
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  void fit(Size size, Size viewport) {
    if (!mounted) return;
    final scale = math.min(1.0,
        math.min(viewport.width / size.width, viewport.height / size.height));
    transform.value = Matrix4.identity()..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final people = {
      for (final relation in widget.relationships) relation.person.id: relation
    };
    final adjacent = <int, Set<int>>{};
    for (final relation in widget.relationships) {
      final source = people.containsKey(relation.relativeToUserId)
          ? relation.relativeToUserId!
          : -1;
      if (source == relation.person.id) continue;
      adjacent.putIfAbsent(source, () => {}).add(relation.person.id);
      adjacent.putIfAbsent(relation.person.id, () => {}).add(source);
    }
    final children = <int, List<int>>{};
    final visited = <int>{};
    final roots = <int>[];
    for (final start in [-1, ...people.keys]) {
      if (!visited.add(start)) continue;
      roots.add(start);
      final queue = [start];
      for (var i = 0; i < queue.length; i++) {
        for (final next in adjacent[queue[i]] ?? <int>{}) {
          if (!visited.add(next)) continue;
          children.putIfAbsent(queue[i], () => []).add(next);
          queue.add(next);
        }
      }
    }
    final positions = <int, Offset>{};
    final stack =
        roots.reversed.map((id) => (id: id, depth: 0, finish: false)).toList();
    var row = 0;
    while (stack.isNotEmpty) {
      final item = stack.removeLast();
      final visible =
          expanded.contains(item.id) ? children[item.id] ?? <int>[] : <int>[];
      if (item.finish) {
        positions[item.id] = Offset(30 + item.depth * 270.0,
            (positions[visible.first]!.dy + positions[visible.last]!.dy) / 2);
      } else if (visible.isNotEmpty) {
        stack.add((id: item.id, depth: item.depth, finish: true));
        for (final id in visible.reversed) {
          stack.add((id: id, depth: item.depth + 1, finish: false));
        }
      } else {
        positions[item.id] =
            Offset(30 + item.depth * 270.0, 30 + row++ * 100.0);
      }
    }
    final size = Size(
        positions.values.fold(500.0, (value, p) => math.max(value, p.dx + 260)),
        positions.values
            .fold(400.0, (value, p) => math.max(value, p.dy + 120)));
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: () =>
                    setState(() => expanded.addAll([-1, ...people.keys])),
                child: const Text('Expand all')),
            OutlinedButton(
                onPressed: () => setState(() {
                      expanded.clear();
                      expanded.add(-1);
                    }),
                child: const Text('Reset branches')),
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Pinch to zoom · Drag to explore')),
          ])),
      Expanded(child: LayoutBuilder(builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (previousSize != size || previousViewport != viewport) {
          previousSize = size;
          previousViewport = viewport;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => fit(size, viewport));
        }
        return Stack(children: [
          InteractiveViewer(
              transformationController: transform,
              constrained: false,
              minScale: .0001,
              maxScale: 3,
              boundaryMargin: const EdgeInsets.all(100),
              child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(children: [
                    CustomPaint(
                        size: size,
                        painter: _ChainPainter(positions, children)),
                    ...positions.entries.map((entry) {
                      final relation = people[entry.key];
                      final name = relation?.person.displayName ??
                          widget.profile?.value('displayName') ??
                          'You';
                      final gender = (relation?.person.gender ??
                              widget.profile?.value('gender') ??
                              '')
                          .toLowerCase();
                      final color = gender == 'male'
                          ? const Color(0xFF3876D6)
                          : gender == 'female'
                              ? const Color(0xFFD53E83)
                              : const Color(0xFF64748B);
                      final count = children[entry.key]?.length ?? 0;
                      void details() {
                        showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            isScrollControlled: true,
                            builder: (sheetContext) => SafeArea(
                                child: SingleChildScrollView(
                                    child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(name.isEmpty ? 'You' : name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineSmall),
                                              Text(relation?.type ?? 'You'),
                                              if (relation?.contactPhone
                                                      ?.isNotEmpty ==
                                                  true)
                                                SelectableText(
                                                    relation!.contactPhone!),
                                              if (relation?.contactEmail
                                                      ?.isNotEmpty ==
                                                  true)
                                                SelectableText(
                                                    relation!.contactEmail!),
                                              if (relation != null)
                                                TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(
                                                          sheetContext);
                                                      widget
                                                          .onDetails(relation);
                                                    },
                                                    child: const Text(
                                                        'Profile & relationship actions')),
                                              if (count > 0)
                                                FilledButton(
                                                    onPressed: () {
                                                      Navigator.pop(
                                                          sheetContext);
                                                      setState(() {
                                                        if (!expanded.remove(
                                                            entry.key)) {
                                                          expanded
                                                              .add(entry.key);
                                                        }
                                                      });
                                                    },
                                                    child: Text(expanded
                                                            .contains(entry.key)
                                                        ? 'Collapse chain'
                                                        : 'Expand chain')),
                                            ])))));
                      }

                      return Positioned(
                          left: entry.value.dx,
                          top: entry.value.dy,
                          width: 235,
                          child: Material(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        InkWell(
                                            onTap: details,
                                            child: Row(children: [
                                              Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: count > 0 ? color : Colors.white,
                                                      border: Border.all(
                                                          color: color,
                                                          width: 3))),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: Text(
                                                      name.isEmpty
                                                          ? 'You'
                                                          : name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500)))
                                            ])),
                                        Row(children: [
                                          Expanded(
                                              child: TextButton(
                                                  onPressed: details,
                                                  child: const Text('Details',
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis))),
                                          if (count > 0)
                                            Expanded(
                                                child: TextButton(
                                                    style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 4)),
                                                    onPressed: () =>
                                                        setState(() {
                                                          if (!expanded.remove(
                                                              entry.key)) {
                                                            expanded
                                                                .add(entry.key);
                                                          }
                                                        }),
                                                    child: Text(
                                                        '${expanded.contains(entry.key) ? '− Collapse' : '+ Chain'} ($count)',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontSize: 14))))
                                          else
                                            const Expanded(
                                                child: Text('End of chain',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        fontSize: 14)))
                                        ]),
                                      ]))));
                    }),
                  ]))),
          Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: 'Fit entire chain',
                  onPressed: () => fit(size, viewport),
                  child: const Icon(Icons.center_focus_strong))),
        ]);
      })),
      const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 90),
          child: Text('Blue: men · Pink: women · Grey: other / unspecified. Filled: has branches. Outlined: end node.',
              style: TextStyle(fontSize: 14))),
    ]);
  }
}

class _ChainPainter extends CustomPainter {
  _ChainPainter(this.positions, this.children);
  final Map<int, Offset> positions;
  final Map<int, List<int>> children;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = const Color(0xFFEAF4F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final entry in children.entries) {
      final a = positions[entry.key];
      if (a == null) continue;
      for (final id in entry.value) {
        final b = positions[id];
        if (b == null) continue;
        final mid = (a.dx + b.dx) / 2;
        canvas.drawPath(
            Path()
              ..moveTo(a.dx + 15, a.dy + 15)
              ..cubicTo(mid, a.dy + 15, mid, b.dy + 15, b.dx + 15, b.dy + 15),
            pen);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChainPainter oldDelegate) => true;
}
