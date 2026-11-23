import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class CommunityActivitiesScreen extends StatefulWidget {
  const CommunityActivitiesScreen(
      {super.key, required this.api, required this.circle});
  final MyAapthaApi api;
  final int circle;
  @override
  State<CommunityActivitiesScreen> createState() =>
      _CommunityActivitiesScreenState();
}

class _CommunityActivitiesScreenState extends State<CommunityActivitiesScreen> {
  List<Map<String, dynamic>> items = [];
  int? more;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({int? before}) async {
    setState(() => busy = true);
    try {
      final page =
          await widget.api.circleActivities(widget.circle, before: before);
      if (mounted) {
        setState(() {
          final rows = (page['items'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          items = before == null ? rows : [...items, ...rows];
          more = page['hasNext'] == true
              ? (page['nextBefore'] as num?)?.toInt()
              : null;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> change(Future<Map<String, dynamic>> Function() task) async {
    setState(() => busy = true);
    try {
      final next = await task();
      if (mounted) {
        setState(() => items =
            items.map((a) => a['id'] == next['id'] ? next : a).toList());
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<DateTime?> pickMoment(DateTime initial) async {
    final day = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day),
        lastDate: DateTime(DateTime.now().year + 10));
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> create(String kind) async {
    final title = TextEditingController(),
        details = TextEditingController(),
        options = TextEditingController(),
        location = TextEditingController();
    bool multiple = false;
    DateTime? start, end;
    String? formError;
    final value = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setModal) => AlertDialog(
                    title: Text(kind == 'POLL' ? 'New poll' : 'New event'),
                    content: SizedBox(
                        width: 440,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              TextField(
                                  controller: title,
                                  maxLength: 200,
                                  decoration: InputDecoration(
                                      labelText: kind == 'POLL'
                                          ? 'Question'
                                          : 'Event name')),
                              TextField(
                                  controller: details,
                                  maxLength: 2000,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                      labelText: 'Details')),
                              if (kind == 'POLL') ...[
                                TextField(
                                    controller: options,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                        labelText: 'Options, one per line')),
                                CheckboxListTile(
                                    value: multiple,
                                    onChanged: (v) =>
                                        setModal(() => multiple = v == true),
                                    title: const Text('Allow multiple answers'))
                              ] else ...[
                                TextButton(
                                    onPressed: () async {
                                      final now = DateTime.now();
                                      final day = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              now.add(const Duration(days: 1)),
                                          firstDate: DateTime(
                                              now.year, now.month, now.day),
                                          lastDate: DateTime(now.year + 10));
                                      if (day == null || !context.mounted) {
                                        return;
                                      }
                                      final time = await showTimePicker(
                                          context: context,
                                          initialTime: const TimeOfDay(
                                              hour: 10, minute: 0));
                                      if (time != null && context.mounted) {
                                        setModal(() => start = DateTime(
                                            day.year,
                                            day.month,
                                            day.day,
                                            time.hour,
                                            time.minute));
                                      }
                                    },
                                    child: Text(start == null
                                        ? 'Choose start time'
                                        : 'Starts: ${start.toString()}')),
                                TextButton(
                                    onPressed: () async {
                                      final value = await pickMoment((start ??
                                              DateTime.now()
                                                  .add(const Duration(days: 1)))
                                          .add(const Duration(hours: 1)));
                                      if (context.mounted) {
                                        setModal(() => end = value);
                                      }
                                    },
                                    child: Text(end == null
                                        ? 'End time (optional)'
                                        : 'Ends: $end')),
                                TextField(
                                    controller: location,
                                    maxLength: 300,
                                    decoration: const InputDecoration(
                                        labelText: 'Location or meeting link'))
                              ],
                              if (formError != null)
                                Text(formError!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () {
                            if (title.text.trim().isEmpty ||
                                kind == 'EVENT' &&
                                    (start == null ||
                                        !start!.isAfter(DateTime.now()) ||
                                        end != null && !end!.isAfter(start!))) {
                              setModal(() => formError =
                                  'Enter a title and a future event time.');
                              return;
                            }
                            final choices = options.text
                                .split('\n')
                                .map((v) => v.trim())
                                .where((v) => v.isNotEmpty)
                                .toList();
                            if (kind == 'POLL' &&
                                (choices.length < 2 ||
                                    choices.length > 12 ||
                                    choices
                                            .map((s) => s.toLowerCase())
                                            .toSet()
                                            .length !=
                                        choices.length)) {
                              setModal(
                                  () => formError = 'Enter 2 to 12 options.');
                              return;
                            }
                            Navigator.pop(context, {
                              'kind': kind,
                              'title': title.text.trim(),
                              'details': details.text.trim(),
                              if (kind == 'POLL') 'options': choices,
                              if (kind == 'POLL') 'multiple': multiple,
                              if (kind == 'EVENT')
                                'startsAt': start!.toUtc().toIso8601String(),
                              if (kind == 'EVENT' && end != null)
                                'endsAt': end!.toUtc().toIso8601String(),
                              if (kind == 'EVENT')
                                'location': location.text.trim()
                            });
                          },
                          child: const Text('Create'))
                    ])));
    title.dispose();
    details.dispose();
    options.dispose();
    location.dispose();
    if (value == null || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.api.createCircleActivity(widget.circle, value);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Polls & events'), actions: [
        IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh))
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          FilledButton(
              onPressed: busy ? null : () => create('POLL'),
              child: const Text('New poll')),
          FilledButton.tonal(
              onPressed: busy ? null : () => create('EVENT'),
              child: const Text('New event'))
        ]),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (busy) const LinearProgressIndicator(),
        if (items.isEmpty && !busy)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No polls or events yet.')),
        for (final item in items)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['title']}',
                            style: Theme.of(context).textTheme.titleLarge),
                        if (item['closed'] == true) const Text('Closed'),
                        if ('${item['details']}'.isNotEmpty)
                          Text('${item['details']}'),
                        if (item['kind'] == 'POLL') ...[
                          for (final raw in item['options'] as List)
                            Builder(builder: (context) {
                              final option =
                                  Map<String, dynamic>.from(raw as Map);
                              return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${option['label']}'),
                                  subtitle: Text('${option['count']} votes'),
                                  value: option['selected'] == true,
                                  onChanged: busy || item['closed'] == true
                                      ? null
                                      : (chosen) {
                                          final ids = <int>[];
                                          if (item['multiple'] == true) {
                                            for (final o
                                                in item['options'] as List) {
                                              if (o['selected'] == true &&
                                                  o['id'] != option['id']) {
                                                ids.add(
                                                    (o['id'] as num).toInt());
                                              }
                                            }
                                          }
                                          if (chosen == true) {
                                            ids.add(
                                                (option['id'] as num).toInt());
                                          }
                                          change(() => widget.api
                                              .voteCircleActivity(
                                                  widget.circle,
                                                  (item['id'] as num).toInt(),
                                                  ids));
                                        });
                            })
                        ] else ...[
                          Text(DateTime.parse('${item['startsAt']}')
                              .toLocal()
                              .toString()),
                          if ('${item['location']}'.isNotEmpty)
                            Text('${item['location']}'),
                          Wrap(spacing: 8, children: [
                            for (final entry in const {
                              'YES': 'Going',
                              'MAYBE': 'Maybe',
                              'NO': 'Not going'
                            }.entries)
                              ChoiceChip(
                                  label: Text(
                                      '${entry.value} (${(item['responses'] as Map)[entry.key] ?? 0})'),
                                  selected: item['myResponse'] == entry.key,
                                  onSelected: busy || item['closed'] == true
                                      ? null
                                      : (_) => change(() => widget.api
                                          .rsvpCircleActivity(
                                              widget.circle,
                                              (item['id'] as num).toInt(),
                                              entry.key)))
                          ])
                        ],
                        if (item['canManage'] == true)
                          Wrap(spacing: 8, children: [
                            if (item['closed'] != true)
                              TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => change(() => widget.api
                                          .closeCircleActivity(widget.circle,
                                              (item['id'] as num).toInt())),
                                  child: const Text('Close activity')),
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final yes = await showDialog<bool>(
                                            context: context,
                                            builder: (c) => AlertDialog(
                                                    title: const Text(
                                                        'Remove activity?'),
                                                    content: const Text(
                                                        'This also removes its responses.'),
                                                    actions: [
                                                      TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  c, false),
                                                          child: const Text(
                                                              'Cancel')),
                                                      FilledButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  c, true),
                                                          child: const Text(
                                                              'Remove'))
                                                    ]));
                                        if (yes != true || !mounted) return;
                                        try {
                                          await widget.api.deleteCircleActivity(
                                              widget.circle,
                                              (item['id'] as num).toInt());
                                          await load();
                                        } catch (e) {
                                          if (mounted) {
                                            setState(() => error = '$e');
                                          }
                                        }
                                      },
                                child: const Text('Remove'))
                          ])
                      ]))),
        if (more != null)
          TextButton(
              onPressed: busy ? null : () => load(before: more),
              child: const Text('Load earlier activities'))
      ]));
}
