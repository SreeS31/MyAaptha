import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class ModerationQueueScreen extends StatefulWidget {
  const ModerationQueueScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends State<ModerationQueueScreen> {
  List<Map<String, dynamic>> reports = [];
  String filter = 'OPEN';
  String? error, message;
  bool loading = false;
  int? cursor, busy;
  int version = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    version++;
    super.dispose();
  }

  bool denied(Object e) =>
      e is MyAapthaApiException && (e.statusCode == 401 || e.statusCode == 403);
  Future<void> load({bool append = false}) async {
    final current = ++version;
    final before = append ? cursor : null;
    setState(() {
      loading = true;
      error = null;
      message = null;
      if (!append) {
        reports = [];
        cursor = null;
      }
    });
    try {
      final page =
          await widget.api.moderationPage(status: filter, beforeId: before);
      if (!mounted || current != version) return;
      final rows = (page['items'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      setState(() {
        reports = append
            ? [
                ...reports,
                ...rows
                    .where((r) => !reports.any((old) => old['id'] == r['id']))
              ]
            : rows;
        cursor = (page['nextCursor'] as num?)?.toInt();
      });
    } catch (e) {
      if (mounted && current == version) {
        setState(() {
          error = e.toString();
          if (denied(e)) {
            reports = [];
            cursor = null;
          }
        });
      }
    } finally {
      if (mounted && current == version) setState(() => loading = false);
    }
  }

  Future<void> decide(Map<String, dynamic> report, String status) async {
    var notes = report['moderatorNotes']?.toString() ?? '';
    final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Mark report as ${status.toLowerCase()}?'),
                content: TextFormField(
                    initialValue: notes,
                    onChanged: (value) => notes = value,
                    maxLength: 2000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Notes visible to the reporter')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save decision'))
                ]));
    final text = notes;
    if (approved != true || !mounted) return;
    final id = (report['id'] as num).toInt();
    final current = version;
    setState(() {
      busy = id;
      error = null;
      message = null;
    });
    try {
      await widget.api.updateModerationReport(id, status, text);
      if (mounted && current == version) {
        setState(() {
          reports = reports
              .map((r) => r['id'] == id
                  ? {...r, 'status': status, 'moderatorNotes': text}
                  : r)
              .where((r) => filter == 'ALL' || r['status'] == filter)
              .toList();
          message = 'Report #$id updated.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          if (denied(e)) {
            reports = [];
            cursor = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: () async {
        if (busy == null) await load();
      },
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(
              child: Text('Moderation queue',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
          IconButton(
              tooltip: 'Refresh queue',
              onPressed: loading || busy != null ? null : () => load(),
              icon: const Icon(Icons.refresh))
        ]),
        const Text('Newest first. Status changes do not remove content.'),
        DropdownButtonFormField<String>(
            initialValue: filter,
            decoration: const InputDecoration(labelText: 'Report status'),
            items: ['OPEN', 'REVIEWING', 'RESOLVED', 'DISMISSED', 'ALL']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: busy != null
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => filter = value);
                    load();
                  }),
        Text('${reports.length} reports loaded'),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (message != null) Text(message!),
        ...reports.map((r) => Card(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${r['id']} · ${r['status']}'),
                      Text('${r['reason']}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (r['details'] != null) Text('${r['details']}'),
                      if (r['moderatorNotes'] != null)
                        Text('Reporter-visible notes: ${r['moderatorNotes']}'),
                      Wrap(
                          spacing: 8,
                          children: ['REVIEWING', 'RESOLVED', 'DISMISSED']
                              .map((s) => TextButton(
                                  onPressed: loading || busy != null
                                      ? null
                                      : () => decide(r, s),
                                  child: Text(s)))
                              .toList())
                    ])))),
        if (cursor != null)
          FilledButton(
              onPressed:
                  loading || busy != null ? null : () => load(append: true),
              child: const Text('Load more reports')),
        if (!loading && reports.isEmpty && error == null)
          const Text('No reports loaded for this status.'),
        if (error != null && !loading)
          TextButton(
              onPressed: () => load(append: cursor != null),
              child: const Text('Retry queue')),
      ]));
}
