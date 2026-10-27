import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class HealthReportDialog extends StatefulWidget {
  const HealthReportDialog(
      {super.key, required this.api, required this.documents});
  final MyAapthaApi api;
  final List<Map<String, dynamic>> documents;
  @override
  State<HealthReportDialog> createState() => _HealthReportDialogState();
}

class _Measurement {
  final name = TextEditingController(),
      value = TextEditingController(),
      unit = TextEditingController(),
      minimum = TextEditingController(),
      maximum = TextEditingController();
  void dispose() {
    for (final c in [name, value, unit, minimum, maximum]) {
      c.dispose();
    }
  }
}

class _HealthReportDialogState extends State<HealthReportDialog> {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  final name = TextEditingController(),
      lab = TextEditingController(),
      notes = TextEditingController();
  final rows = <_Measurement>[_Measurement()];
  final removed = <_Measurement>[];
  DateTime collected = DateUtils.dateOnly(DateTime.now());
  int? postId;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    scroll.dispose();
    name.dispose();
    lab.dispose();
    notes.dispose();
    for (final r in [...rows, ...removed]) {
      r.dispose();
    }
    super.dispose();
  }

  String get date =>
      '${collected.year.toString().padLeft(4, '0')}-${collected.month.toString().padLeft(2, '0')}-${collected.day.toString().padLeft(2, '0')}';
  String? requiredText(String? value, int max) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    if (text.length > max) return 'Maximum $max characters';
    return null;
  }

  String? number(String? value, {bool required = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? 'Required' : null;
    final parsed = double.tryParse(text);
    if (parsed == null || !parsed.isFinite || parsed.abs() > 1000000000) {
      return 'Enter a number between -1000000000 and 1000000000';
    }
    return null;
  }

  Future<void> save() async {
    if (saving) return;
    final invalid = form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && invalid.first.mounted) {
          Scrollable.ensureVisible(invalid.first.context, alignment: 0.1);
        }
      });
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.addHealthReport({
        'reportName': name.text.trim(),
        'laboratory': lab.text.trim(),
        'notes': notes.text.trim(),
        'collectedOn': date,
        'sourcePostId': postId,
        'measurements': rows
            .map((r) => {
                  'metricName': r.name.text.trim(),
                  'value': double.parse(r.value.text.trim()),
                  'unit': r.unit.text.trim(),
                  'referenceMin': double.tryParse(r.minimum.text.trim()),
                  'referenceMax': double.tryParse(r.maximum.text.trim())
                })
            .toList()
      });
      if (mounted) {
        setState(() => saving = false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e.toString();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && scroll.hasClients) {
            scroll.jumpTo(0);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: const Text('Add diagnostic report'),
        content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
                controller: scroll,
                child: Form(
                    key: form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (error != null)
                        Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      TextFormField(
                          controller: name,
                          enabled: !saving,
                          maxLength: 200,
                          decoration:
                              const InputDecoration(labelText: 'Report name'),
                          validator: (s) => requiredText(s, 200)),
                      TextFormField(
                          controller: lab,
                          enabled: !saving,
                          maxLength: 200,
                          decoration:
                              const InputDecoration(labelText: 'Laboratory')),
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Collection date'),
                          subtitle: Text(date),
                          trailing: const Icon(Icons.calendar_month),
                          onTap: saving
                              ? null
                              : () async {
                                  final chosen = await showDatePicker(
                                      context: context,
                                      initialDate: collected,
                                      firstDate: DateTime(1),
                                      lastDate: DateTime.now());
                                  if (chosen != null && mounted) {
                                    setState(() => collected = chosen);
                                  }
                                }),
                      DropdownButtonFormField<int?>(
                          initialValue: postId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Private diary document'),
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null, child: Text('No linked document')),
                            ...widget.documents.map((d) =>
                                DropdownMenuItem<int?>(
                                    value: d['id'] as int,
                                    child: Text('${d['name']}',
                                        overflow: TextOverflow.ellipsis)))
                          ],
                          onChanged: saving
                              ? null
                              : (v) => setState(() => postId = v)),
                      TextFormField(
                          controller: notes,
                          enabled: !saving,
                          maxLength: 1000,
                          maxLines: 2,
                          decoration:
                              const InputDecoration(labelText: 'Notes')),
                      ...rows.asMap().entries.map((entry) {
                        final r = entry.value, index = entry.key;
                        return Column(key: ObjectKey(r), children: [
                          Row(children: [
                            Expanded(
                                child: Text('Measurement ${index + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            if (rows.length > 1)
                              IconButton(
                                  tooltip: 'Remove measurement ${index + 1}',
                                  onPressed: saving
                                      ? null
                                      : () {
                                          setState(() {
                                            rows.remove(r);
                                            removed.add(r);
                                          });
                                        },
                                  icon: const Icon(Icons.remove_circle_outline))
                          ]),
                          TextFormField(
                              controller: r.name,
                              enabled: !saving,
                              maxLength: 120,
                              decoration: InputDecoration(
                                  labelText: 'Metric ${index + 1}'),
                              validator: (s) => requiredText(s, 120)),
                          TextFormField(
                              controller: r.value,
                              enabled: !saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              decoration: InputDecoration(
                                  labelText: 'Value ${index + 1}'),
                              validator: (s) => number(s, required: true)),
                          TextFormField(
                              controller: r.unit,
                              enabled: !saving,
                              maxLength: 40,
                              decoration: InputDecoration(
                                  labelText: 'Unit ${index + 1}'),
                              validator: (s) => requiredText(s, 40)),
                          TextFormField(
                              controller: r.minimum,
                              enabled: !saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              decoration: InputDecoration(
                                  labelText: 'Lab minimum ${index + 1}'),
                              validator: (s) => number(s)),
                          TextFormField(
                              controller: r.maximum,
                              enabled: !saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              decoration: InputDecoration(
                                  labelText: 'Lab maximum ${index + 1}'),
                              validator: (s) {
                                final invalid = number(s);
                                if (invalid != null) return invalid;
                                final min =
                                        double.tryParse(r.minimum.text.trim()),
                                    max = double.tryParse(s?.trim() ?? '');
                                return min != null && max != null && min > max
                                    ? 'Minimum cannot exceed maximum'
                                    : null;
                              }),
                        ]);
                      }),
                      TextButton.icon(
                          onPressed: saving || rows.length >= 500
                              ? null
                              : () => setState(() => rows.add(_Measurement())),
                          icon: const Icon(Icons.add),
                          label: const Text('Add measurement')),
                    ])))),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving...' : 'Save report'))
        ],
      ));
}
