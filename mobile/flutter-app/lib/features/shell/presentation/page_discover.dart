import 'package:flutter/material.dart';

class PageDiscoverButton extends StatelessWidget {
  const PageDiscoverButton({super.key, required this.root});
  final GlobalKey root;
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

    final page = root.currentContext;
    if (page is Element) visit(page);
    var query = '';
    final chosen = await showDialog<BuildContext>(
        context: context,
        builder: (dialog) => StatefulBuilder(builder: (context, setState) {
              final term = query.trim().toLowerCase(),
                  matches = entries
                      .where((entry) =>
                          term.isNotEmpty &&
                          entry.$1.toLowerCase().contains(term))
                      .toList();
              return AlertDialog(
                  title: const Text('Discover on this page'),
                  content: SizedBox(
                      width: 440,
                      height: 360,
                      child: Column(children: [
                        TextField(
                            autofocus: true,
                            decoration: const InputDecoration(
                                labelText: 'Search this page',
                                prefixIcon: Icon(Icons.search)),
                            onChanged: (value) => setState(() {
                                  query = value;
                                })),
                        const SizedBox(height: 8),
                        Expanded(
                            child: term.isEmpty
                                ? const Center(
                                    child: Text('Search the current page'))
                                : matches.isEmpty
                                    ? const Center(
                                        child: Text('No matches on this page'))
                                    : ListView.builder(
                                        itemCount: matches.length,
                                        itemBuilder: (_, index) => ListTile(
                                            title: Text(matches[index].$1),
                                            onTap: () => Navigator.pop(
                                                dialog, matches[index].$2))))
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('Close'))
                  ]);
            }));
    if (chosen != null && chosen.mounted) {
      await Scrollable.ensureVisible(chosen,
          alignment: .4,
          duration: MediaQuery.of(chosen).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
      onPressed: () => discover(context),
      icon: const Icon(Icons.search, size: 20),
      label: const Text('Discover'));
}
