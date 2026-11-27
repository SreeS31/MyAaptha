import 'package:flutter/material.dart';
import '../../../core/network/myaaptha_api.dart';
import '../../../core/models/network_models.dart';

class PageDiscoverButton extends StatelessWidget {
  const PageDiscoverButton(
      {super.key, required this.root, this.api, this.onPerson, this.onCircle});
  final GlobalKey root;
  final MyAapthaApi? api;
  final ValueChanged<Person>? onPerson;
  final ValueChanged<CircleModel>? onCircle;
  Future<void> discover(BuildContext context) async {
    final entries = <(String, BuildContext)>[];
    final seen = <String>{};
    void visit(Element element) {
      if (!Visibility.of(element)) return;
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (widget is Text) {
        final text = (widget.data ?? widget.textSpan?.toPlainText() ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (text.isNotEmpty && seen.add(text)) entries.add((text, element));
        return;
      }
      element.visitChildren(visit);
    }

    final rootContext = root.currentContext;
    if (rootContext is Element) visit(rootContext);
    String query = '';
    List<PeopleMatch> people = [];
    List<CircleModel> circles = [];
    bool loading = false, searched = false;
    String? error;
    int version = 0;
    final chosen = await showDialog<Object>(
        context: context,
        builder: (dialog) => StatefulBuilder(builder: (context, setState) {
              Future<void> search() async {
                final current = ++version;
                setState(() {
                  searched = true;
                  loading = api != null;
                  error = null;
                  people = [];
                  circles = [];
                });
                if (api == null) return;
                try {
                  final term = query.trim().toLowerCase();
                  final values = await Future.wait<dynamic>([
                    term.length >= 2
                        ? api!.discoverPeople(query.trim())
                        : Future.value(null),
                    api!.circles()
                  ]);
                  if (!dialog.mounted || current != version) return;
                  setState(() {
                    people = (values[0] as PeopleDiscovery?)?.people ?? [];
                    circles = (values[1] as List<CircleModel>)
                        .where((c) => c.name.toLowerCase().contains(term))
                        .toList();
                    loading = false;
                  });
                } catch (_) {
                  if (dialog.mounted && current == version) {
                    setState(() {
                      loading = false;
                      error = 'Some results are unavailable. Try again.';
                    });
                  }
                }
              }

              final term = query.trim().toLowerCase(),
                  matches = entries
                      .where((entry) =>
                          term.isNotEmpty &&
                          entry.$1.toLowerCase().contains(term))
                      .toList();
              return AlertDialog(
                  title: const Text('Find people & Circles'),
                  content: SizedBox(
                      width: 460,
                      height: 420,
                      child: Column(children: [
                        TextField(
                            autofocus: true,
                            decoration: const InputDecoration(
                                labelText:
                                    'Search this page, people or circles',
                                prefixIcon: Icon(Icons.search)),
                            onChanged: (value) => setState(() {
                                  version++;
                                  query = value;
                                  searched = false;
                                  loading = false;
                                }),
                            onSubmitted: (_) => search()),
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                onPressed: query.trim().isEmpty ? null : search,
                                child: const Text('Search'))),
                        Expanded(
                            child: ListView(children: [
                          const Text('This page',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          if (term.isEmpty)
                            const Text('Enter a name or search term')
                          else if (matches.isEmpty)
                            const Text('No matches on this page')
                          else
                            ...matches.map((m) => ListTile(
                                title: Text(m.$1),
                                onTap: () => Navigator.pop(dialog, m.$2))),
                          if (loading) const LinearProgressIndicator(),
                          if (searched && !loading) ...[
                            const Text('People',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            if (people.isEmpty)
                              const Text('No matching people'),
                            ...people.map((m) => ListTile(
                                title: Text(m.person.displayName),
                                onTap: () => Navigator.pop(dialog, m.person))),
                            const Text('Circles',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            if (circles.isEmpty)
                              const Text('No matching circles'),
                            ...circles.map((c) => ListTile(
                                title: Text(c.name),
                                onTap: () => Navigator.pop(dialog, c)))
                          ],
                          if (error != null) Text(error!)
                        ]))
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('Close'))
                  ]);
            }));
    version++;
    if (chosen is BuildContext && chosen.mounted) {
      await Scrollable.ensureVisible(chosen,
          alignment: .4,
          duration: MediaQuery.of(chosen).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 200));
    } else if (chosen is Person) {
      onPerson?.call(chosen);
    } else if (chosen is CircleModel) {
      onCircle?.call(chosen);
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
      message: 'Find people & Circles',
      child: MediaQuery.sizeOf(context).width < 520
          ? IconButton(
              tooltip: 'Find people & Circles',
              onPressed: () => discover(context),
              icon: const Icon(Icons.search))
          : TextButton.icon(
              onPressed: () => discover(context),
              icon: const Icon(Icons.search, size: 20),
              label: const Text('Find people & Circles')));
}
