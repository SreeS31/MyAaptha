import 'dart:math' as math;
import 'app_shell.dart' show DirectChatScreen;
import '../../../core/models/network_models.dart';
import 'package:flutter/material.dart';
import '../../../core/network/myaaptha_api.dart';

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
  final open = <int>{}, loading = <int>{};
  final trees = <int, Map<String, dynamic>>{},
      errors = <int, String>{},
      generations = <int, int>{},
      limits = <int, int>{};
  final transform = TransformationController();
  int? active, focus;
  Map<String, dynamic>? selected;
  Future<Map<String, dynamic>>? info;
  String? previousLayout;
  Size? previousViewport;
  @override
  void didUpdateWidget(covariant SavedTreeDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.cards.map((card) => (card['id'] as num).toInt()).toSet();
    for (final id in open.toList()) {
      final old = oldWidget.cards.where((card) => card['id'] == id).firstOrNull;
      final card = widget.cards.where((card) => card['id'] == id).firstOrNull;
      if (!ids.contains(id)) {
        open.remove(id);
        trees.remove(id);
        loading.remove(id);
        errors.remove(id);
        generations[id] = (generations[id] ?? 0) + 1;
        if (selected?['treeId'] == id) {
          selected = null;
          info = null;
        }
      } else if (old?['version'] != card?['version']) {
        if (selected?['treeId'] == id) {
          selected = null;
          info = null;
        }
        Future.microtask(() {
          if (mounted && open.contains(id)) {
            load(id);
          }
        });
      }
    }
    if (!ids.contains(active)) {
      active = null;
    }
    if (!ids.contains(focus)) {
      focus = null;
    }
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  Future<void> load(int id) async {
    final generation = (generations[id] ?? 0) + 1;
    generations[id] = generation;
    setState(() {
      loading.add(id);
      errors.remove(id);
      trees.remove(id);
    });
    try {
      final tree =
          await widget.api.reviewedRelationshipTree('$id', saved: true);
      if (mounted && generations[id] == generation && open.contains(id)) {
        setState(() => trees[id] = tree);
      }
    } catch (e) {
      if (mounted && generations[id] == generation && open.contains(id)) {
        setState(() => errors[id] = '$e');
      }
    } finally {
      if (mounted && generations[id] == generation) {
        setState(() => loading.remove(id));
      }
    }
  }

  void toggle(int id) {
    setState(() {
      active = id;
      if (open.remove(id)) {
        generations[id] = (generations[id] ?? 0) + 1;
        trees.remove(id);
        loading.remove(id);
        errors.remove(id);
        if (selected?['treeId'] == id) {
          selected = null;
          info = null;
        }
        focus = null;
        active = open.isEmpty ? null : open.last;
      } else {
        open.add(id);
        focus = id;
      }
    });
    if (open.contains(id)) {
      load(id);
    }
  }

  void choose(_Group group, _Person person) {
    final local = <String, dynamic>{
      ...person.node,
      'phones': <String>[],
      'emails': <String>[],
      'organization': '',
      'groups': <String>[],
      'contactAvailable': false
    };
    final request = person.node['contactId'] == null
        ? Future.value(local)
        : widget.api
            .reviewedTreePersonInfo(group.id, person.node['key'] as String);
    setState(() {
      selected = {
        ...person.node,
        'treeId': group.id,
        'treeName': group.card['name']
      };
      info = request;
      active = group.id;
    });
    if (MediaQuery.sizeOf(context).width < 900) {
      showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => SafeArea(
              child: SingleChildScrollView(
                  child: _Basics(
                      api: widget.api,
                      node: selected!,
                      request: request,
                      onClose: () => Navigator.pop(context),
                      onEdit: () {
                        Navigator.pop(context);
                        widget.onEdit(group.card, person.node['key'] as String);
                      }))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups(widget.cards, trees, open, limits);
    final extent =
        groups.fold<double>(0, (value, g) => math.max(value, g.radius));
    final radius = math.max(
        245.0,
        (extent > 0 ? extent + 140 : 110) /
            math.sin(math.pi / math.max(2, groups.length)));
    final size = 2 * (radius + extent + 120),
        center = Offset(size / 2, size / 2);
    for (int i = 0; i < groups.length; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / groups.length;
      groups[i].center =
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    }
    final current = groups.where((g) => g.id == active).firstOrNull;
    final canvas = SizedBox(
        height: 560,
        child: LayoutBuilder(builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, 560),
              signature =
                  '$focus:$size:${groups.map((g) => g.people.length).join(',')}';
          if (previousLayout != signature || previousViewport != viewport) {
            previousLayout = signature;
            previousViewport = viewport;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final chosen = groups.where((g) => g.id == focus).firstOrNull;
              final around = chosen == null ? size / 2 : chosen.radius + 110,
                  target = chosen?.center ?? center;
              final scale = chosen != null
                  ? 1.0
                  : math.min(
                      1.0,
                      math.min(viewport.width / (around * 2),
                          viewport.height / (around * 2)));
              transform.value = Matrix4.identity()
                ..translateByDouble(viewport.width / 2 - target.dx * scale,
                    viewport.height / 2 - target.dy * scale, 0, 1)
                ..scaleByDouble(scale, scale, scale, 1);
            });
          }
          return ClipRect(
              child: InteractiveViewer(
                  transformationController: transform,
                  constrained: false,
                  minScale: .01,
                  maxScale: 2,
                  child: SizedBox(
                      width: size,
                      height: size,
                      child: Stack(children: [
                        Positioned.fill(
                            child:
                                CustomPaint(painter: _Lines(center, groups))),
                        Positioned(
                            left: center.dx - 43,
                            top: center.dy - 43,
                            width: 86,
                            height: 86,
                            child: const CircleAvatar(child: Text('You'))),
                        for (final group in groups) ...[
                          Positioned(
                              left: group.center.dx - 80,
                              top: group.center.dy - 39,
                              width: 160,
                              height: 78,
                              child: OutlinedButton(
                                  onPressed: widget.busy
                                      ? null
                                      : () => toggle(group.id),
                                  style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.all(6),
                                      backgroundColor: open.contains(group.id)
                                          ? const Color(0xffe6f2ef)
                                          : Colors.white),
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(group.card['name'] as String,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center),
                                        Text(
                                            '${group.card['count']} people ${open.contains(group.id) ? '-' : '+'}',
                                            style:
                                                const TextStyle(fontSize: 12))
                                      ]))),
                          for (final person in group.people)
                            Positioned(
                                left: group.center.dx + person.offset.dx - 75,
                                top: group.center.dy + person.offset.dy - 30,
                                width: 150,
                                height: 60,
                                child: OutlinedButton(
                                    onPressed: () => choose(group, person),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                            color: _color(person.node),
                                            width: 2)),
                                    child: Row(children: [
                                      Expanded(
                                          child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(person.node['name'] as String,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 13)),
                                            Text(
                                                person.node['relation']
                                                    as String,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 11))
                                          ])),
                                      Icon(
                                          person.hasChildren
                                              ? Icons.circle
                                              : Icons.circle_outlined,
                                          size: 12,
                                          color: _color(person.node))
                                    ])))
                        ]
                      ]))));
        }));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
                onPressed: () => setState(() {
                      focus = null;
                      previousLayout = null;
                    }),
                child: const Text('Overview')),
            TextButton(
                onPressed: () => setState(() {
                      for (final id in open) {
                        generations[id] = (generations[id] ?? 0) + 1;
                      }
                      open.clear();
                      trees.clear();
                      loading.clear();
                      errors.clear();
                      selected = null;
                      focus = null;
                    }),
                child: const Text('Collapse all')),
            if (current != null && open.contains(current.id)) ...[
              Text(current.card['name'] as String),
              TextButton(
                  onPressed: trees[current.id] == null
                      ? null
                      : () => widget.onEdit(current.card, null),
                  child: const Text('Edit tree')),
              TextButton(
                  onPressed:
                      widget.busy ? null : () => widget.onDelete(current.card),
                  child: const Text('Delete tree'))
            ]
          ]),
      for (final id in loading)
        Text(
            'Loading ${widget.cards.firstWhere((c) => c['id'] == id)['name']}...'),
      for (final entry in errors.entries)
        Row(children: [
          Expanded(child: Text(entry.value)),
          TextButton(
              onPressed: () => load(entry.key), child: const Text('Retry'))
        ]),
      if (MediaQuery.sizeOf(context).width >= 900 && selected != null)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: canvas),
          SizedBox(
              width: 300,
              child: _Basics(
                  api: widget.api,
                  key: ValueKey('${selected!['treeId']}:${selected!['key']}'),
                  node: selected!,
                  request: info!,
                  onClose: () => setState(() => selected = null),
                  onEdit: () => widget.onEdit(
                      widget.cards
                          .firstWhere((c) => c['id'] == selected!['treeId']),
                      selected!['key'] as String)))
        ])
      else
        canvas,
      for (final group in groups)
        if (group.people.length < group.total)
          TextButton(
              onPressed: () => setState(() {
                    limits[group.id] = (limits[group.id] ?? 80) + 100;
                    focus = group.id;
                  }),
              child: Text(
                  'Show more in ${group.card['name']} (${group.people.length} of ${group.total})'))
    ]);
  }
}

Color _color(Map<String, dynamic> node) => node['gender'] == 'MALE'
    ? const Color(0xff326bc4)
    : node['gender'] == 'FEMALE'
        ? const Color(0xffbe3273)
        : const Color(0xff64748b);

class _Person {
  _Person(this.node, this.offset, this.hasChildren);
  final Map<String, dynamic> node;
  final Offset offset;
  final bool hasChildren;
}

class _Group {
  _Group(this.id, this.card, this.people, this.radius, this.total);
  final int id, total;
  final Map<String, dynamic> card;
  final List<_Person> people;
  final double radius;
  Offset center = Offset.zero;
}

List<_Group> _groups(List<Map<String, dynamic>> cards,
    Map<int, Map<String, dynamic>> trees, Set<int> open, Map<int, int> limits) {
  return cards.map((card) {
    final id = (card['id'] as num).toInt();
    final List<dynamic> nodes = open.contains(id)
        ? ((trees[id]?['nodes'] as List?) ?? <dynamic>[])
        : <dynamic>[];
    final byParent = <String?, List<Map<String, dynamic>>>{};
    for (final raw in nodes) {
      final node = Map<String, dynamic>.from(raw as Map);
      byParent.putIfAbsent(node['parentKey'] as String?, () => []).add(node);
    }
    final stack = (byParent[null] ?? []).reversed.toList(),
        seen = <String>{},
        ordered = <Map<String, dynamic>>[];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (!seen.add(node['key'] as String)) continue;
      ordered.add(node);
      stack.addAll((byParent[node['key']] ?? []).reversed);
    }
    final shown = ordered.take(limits[id] ?? 80).toList(), people = <_Person>[];
    int used = 0, ring = 0;
    double radius = 0;
    while (used < shown.length) {
      radius = 180 + ring * 180.0;
      final count =
          math.min(shown.length - used, (2 * math.pi * radius / 180).floor());
      for (int i = 0; i < count; i++) {
        final angle = -math.pi / 2 + 2 * math.pi * i / count;
        final node = shown[used + i];
        people.add(_Person(
            node,
            Offset(math.cos(angle) * radius, math.sin(angle) * radius),
            byParent.containsKey(node['key'])));
      }
      used += count;
      ring++;
    }
    return _Group(id, card, people, radius, nodes.length);
  }).toList();
}

class _Lines extends CustomPainter {
  _Lines(this.center, this.groups);
  final Offset center;
  final List<_Group> groups;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff9bbfc1)
      ..strokeWidth = 2;
    for (final group in groups) {
      canvas.drawLine(center, group.center, paint);
      final byKey = {
        for (final person in group.people) person.node['key']: person
      };
      for (final person in group.people) {
        final parent = byKey[person.node['parentKey']];
        canvas.drawLine(group.center + (parent?.offset ?? Offset.zero),
            group.center + person.offset, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Lines old) =>
      old.groups != groups || old.center != center;
}

class _Basics extends StatelessWidget {
  const _Basics(
      {super.key,
      required this.api,
      required this.node,
      required this.request,
      required this.onClose,
      required this.onEdit});
  final MyAapthaApi api;
  final Map<String, dynamic> node;
  final Future<Map<String, dynamic>> request;
  final VoidCallback onClose, onEdit;
  @override
  Widget build(BuildContext context) {
    final name = node['name'] as String;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) =>
            part.isEmpty ? '' : String.fromCharCodes(part.runes.take(1)))
        .join()
        .toUpperCase();
    Widget field(String label, String value, {bool empty = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff607383))),
          TextSpan(
              text: value,
              style: TextStyle(
                  fontSize: empty ? 13 : 14,
                  fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
                  fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                  color: empty
                      ? const Color(0xff667684)
                      : const Color(0xff183047)))
        ])));
    return Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xffd8e5e6))),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: FutureBuilder<Map<String, dynamic>>(
                future: request,
                builder: (context, snapshot) {
                  final info = snapshot.data;
                  final phones = (info?['phones'] as List? ?? []).join(', '),
                      emails = (info?['emails'] as List? ?? []).join(', '),
                      organization = info?['organization'] as String? ?? '';
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xffdceee8),
                              child: Text(initials,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xff205d65)))),
                          const SizedBox(width: 9),
                          Expanded(
                              child: Text(name,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xff16373e)))),
                          TextButton(
                              onPressed: onClose,
                              child: const Text('Close',
                                  style: TextStyle(fontSize: 12)))
                        ]),
                        const Divider(height: 20, color: Color(0xffe5eded)),
                        field('Tree', '${node['treeName']}'),
                        field('Relationship', '${node['relation']}'),
                        field(
                            'Gender',
                            node['gender'] == 'MALE'
                                ? 'Man'
                                : node['gender'] == 'FEMALE'
                                    ? 'Woman'
                                    : node['gender'] == 'OTHER'
                                        ? 'Other'
                                        : 'Unspecified'),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const LinearProgressIndicator(),
                        if (snapshot.hasError)
                          const Text(
                              'Contact details could not be loaded. Close and select the person to retry.'),
                        if (info != null) ...[
                          const Divider(height: 16, color: Color(0xffedf1f3)),
                          field('Phone', phones.isEmpty ? 'Not saved' : phones,
                              empty: phones.isEmpty),
                          field('Email', emails.isEmpty ? 'Not saved' : emails,
                              empty: emails.isEmpty),
                          field('Organization',
                              organization.isEmpty ? 'Not saved' : organization,
                              empty: organization.isEmpty),
                          if ((info['groups'] as List? ?? []).isNotEmpty)
                            field('Contact groups',
                                (info['groups'] as List).join(', '))
                        ],
                        const SizedBox(height: 10),
                        _TreeMessageButton(
                            key: ValueKey('${node['treeId']}:${node['key']}'),
                            api: api,
                            node: node,
                            ready: info != null),
                        SizedBox(
                            width: double.infinity,
                            child: TextButton(
                                onPressed: onEdit,
                                child: const Text('Edit person')))
                      ]);
                })));
  }
}

class _TreeMessageButton extends StatefulWidget {
  const _TreeMessageButton(
      {super.key, required this.api, required this.node, required this.ready});
  final MyAapthaApi api;
  final Map<String, dynamic> node;
  final bool ready;
  @override
  State<_TreeMessageButton> createState() => _TreeMessageButtonState();
}

class _TreeMessageButtonState extends State<_TreeMessageButton> {
  bool busy = false;
  String? error;
  Future<void> message() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final target = await widget.api.reviewedTreeMessageTarget(
          (widget.node['treeId'] as num).toInt(), widget.node['key'] as String);
      if (!mounted) return;
      if (target['userId'] == null) {
        setState(() =>
            error = 'This person is not available for MyAaptha messaging.');
        return;
      }
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DirectChatScreen(
                  api: widget.api,
                  contactId: (target['contactId'] as num?)?.toInt(),
                  person: Person(
                      id: (target['userId'] as num).toInt(),
                      displayName: target['name'] as String? ??
                          widget.node['name'] as String,
                      accountStatus: 'ACTIVE',
                      identityType: 'ACCOUNT'))));
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to open chat. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton.icon(
            onPressed: busy || !widget.ready ? null : message,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: Text(busy ? 'Opening chat...' : 'Message')),
        if (error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(error!, style: const TextStyle(fontSize: 12)))
      ]);
}
