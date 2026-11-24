import 'package:flutter/material.dart';
import '../../../core/network/myaaptha_api.dart';

class PeopleHighlights extends StatefulWidget {
  const PeopleHighlights({super.key, required this.api, this.refresh = 0,this.showHeading=true});
  final MyAapthaApi api;
  final int refresh;
  final bool showHeading;
  @override
  State<PeopleHighlights> createState() => _HighlightsState();
}

class _HighlightsState extends State<PeopleHighlights> {
  String view = 'frequent';
  List<Map<String, dynamic>> items = [];
  bool enabled = true, busy = false;
  String? error;
  int? more;
  int sequence = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant PeopleHighlights old) {
    super.didUpdateWidget(old);
    if (old.refresh != widget.refresh) {
      load();
    }
  }

  Future<void> load({int after = 0}) async {
    final current = ++sequence;
    setState(() => busy = true);
    try {
      final page =
          await widget.api.peopleHighlights(view: view, afterId: after);
      if (mounted && current == sequence) {
        setState(() {
          items = [
            if (after > 0) ...items,
            ...(page['items'] as List)
                .map((v) => Map<String, dynamic>.from(v as Map))
          ];
          enabled = page['enabled'] == true;
          more = (page['nextCursor'] as num?)?.toInt();
          error = null;
        });
      }
    } catch (e) {
      if (mounted && current == sequence) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted && current == sequence) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> change(Map<String, dynamic> p,
      {bool? star, bool? hidden}) async {
    setState(() => busy = true);
    try {
      await widget.api.chooseHighlight(
          memberId: (p['memberId'] as num?)?.toInt(),
          contactId: (p['contactId'] as num?)?.toInt(),
          starred: star ?? p['starred'] == true,
          hidden: hidden ?? p['hidden'] == true);
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if(widget.showHeading)const Text('People highlights',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Suggest frequent callers'),
                value: enabled,
                onChanged: busy
                    ? null
                    : (value) async {
                        setState(() => busy = true);
                        try {
                          await widget.api.highlightPreferences(value);
                          await load();
                        } catch (e) {
                          if (mounted) {
                            setState(() => error = '$e');
                          }
                        } finally {
                          if (mounted) {
                            setState(() => busy = false);
                          }
                        }
                      }),
            Wrap(spacing: 6, children: [
              for (final v in ['frequent', 'starred', 'hidden'])
                ChoiceChip(
                    label: Text(v == 'frequent'
                        ? 'Frequent'
                        : v == 'starred'
                            ? 'Starred'
                            : 'Hidden'),
                    selected: view == v,
                    onSelected: (_) {
                      setState(() => view = v);
                      load();
                    })
            ]),
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(error!),
            if (!busy && items.isEmpty)
              Text(view == 'frequent'
                  ? (enabled
                      ? 'Suggestions appear after two answered MyAaptha calls in 90 days.'
                      : 'Frequent-call suggestions are off.')
                  : view == 'starred'
                      ? 'Star people from contacts or frequent callers.'
                      : 'No hidden suggestions.'),
            ...items.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if ((p['connectedCalls'] as num) > 0)
                        Text(
                            "${p['connectedCalls']} answered calls in 90 days"),
                      Wrap(spacing: 8, children: [
                        TextButton(
                            onPressed: busy
                                ? null
                                : () => change(p, star: p['starred'] != true),
                            child:
                                Text(p['starred'] == true ? 'Unstar' : 'Star')),
                        if (view == 'frequent')
                          TextButton(
                              onPressed:
                                  busy ? null : () => change(p, hidden: true),
                              child: const Text('Hide')),
                        if (view == 'hidden')
                          TextButton(
                              onPressed:
                                  busy ? null : () => change(p, hidden: false),
                              child: const Text('Restore'))
                      ])
                    ]))),
            if (more != null)
              TextButton(
                  onPressed: busy ? null : () => load(after: more!),
                  child: const Text('Load more people'))
          ])));
}
