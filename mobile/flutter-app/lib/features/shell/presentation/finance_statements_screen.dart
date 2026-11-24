import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/network/myaaptha_api.dart';

const statementCategories = [
  'GROCERIES',
  'CLOTHING',
  'SHOPPING',
  'FOOD',
  'UTILITIES',
  'BILLS',
  'HOUSING',
  'TRANSPORT',
  'TRAVEL',
  'HEALTH',
  'INSURANCE',
  'EDUCATION',
  'ENTERTAINMENT',
  'INVESTMENT',
  'TAX',
  'FEES',
  'SALARY',
  'BUSINESS',
  'INTEREST',
  'REFUND',
  'INCOME',
  'TRANSFER',
  'OTHER'
];
const reportZones = [
  'Asia/Kolkata',
  'UTC',
  'America/New_York',
  'Europe/London',
  'Asia/Dubai',
  'Australia/Sydney'
];

class FinanceStatementsScreen extends StatefulWidget {
  const FinanceStatementsScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<FinanceStatementsScreen> createState() => _FinanceStatementsState();
}

class _FinanceStatementsState extends State<FinanceStatementsScreen> {
  String period = 'MONTH',
      anchor = DateTime.now().toIso8601String().substring(0, 7),
      zone = 'Asia/Kolkata',
      order = 'DMY';
  final account = TextEditingController();
  Map<String, dynamic>? report, preview;
  final selected = <String>{};
  bool busy = false;
  String? error, notice;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    account.dispose();
    super.dispose();
  }

  String money(dynamic value) =>
      'INR ${(value as num? ?? 0).toStringAsFixed(2)}';
  Future<void> load() async {
    final sequence = ++generation;
    setState(() => busy = true);
    try {
      final value = await widget.api.financialReport(period, anchor, zone);
      if (mounted && sequence == generation) {
        setState(() {
          report = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && sequence == generation) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted && sequence == generation) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> pickStatement() async {
    if (account.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Add an account label first. Use the same label each time.')));
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv', 'xlsx', 'pdf', 'tsv', 'txt'],
          withData: false,
          withReadStream: true);
      if (result == null) {
        return;
      }
      final file = result.files.single;
      if (file.size == 0 || file.size > 10 * 1024 * 1024) {
        throw const FormatException('Choose a statement up to 10 MB.');
      }
      final stream = file.readStream;
      if (stream == null && file.bytes == null) {
        throw const FormatException('This file could not be opened.');
      }
      final builder = BytesBuilder(copy: false);
      if (stream != null) {
        await for (final chunk in stream) {
          if (builder.length + chunk.length > 10 * 1024 * 1024) {
            throw const FormatException('Statement exceeds 10 MB.');
          }
          builder.add(chunk);
        }
      } else {
        builder.add(file.bytes!);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        busy = true;
        error = null;
        notice = null;
        preview = null;
        selected.clear();
      });
      final value = await widget.api.previewFinancialStatement(
          builder.takeBytes(), file.name, account.text.trim(), order, zone);
      if (mounted) {
        setState(() {
          preview = value;
          for (final row in value['rows'] as List) {
            if (row['duplicate'] != true &&
                row['possibleDuplicate'] != true &&
                (row['issues'] as List).isEmpty) {
              selected.add(row['sourceKey'] as String);
            }
          }
        });
      }
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

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final rows = (preview!['rows'] as List)
          .where((r) => selected.contains(r['sourceKey']))
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final result =
          await widget.api.commitFinancialStatement(account.text.trim(), rows);
      if (mounted) {
        setState(() {
          notice =
              "${result['imported']} transactions saved; ${result['duplicates']} duplicates skipped.";
          preview = null;
          selected.clear();
        });
        await load();
      }
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

  Future<void> export() async {
    setState(() => busy = true);
    try {
      final bytes =
          await widget.api.exportFinancialReport(period, anchor, zone);
      await FilePicker.platform.saveFile(
          dialogTitle: 'Export financial report',
          fileName: 'MyAaptha-${period.toLowerCase()}-$anchor.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
          bytes: bytes);
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

  Widget purpose(String value, ValueChanged<String?>? changed) =>
      DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: value,
          decoration: const InputDecoration(labelText: 'Purpose'),
          items: statementCategories
              .map((category) => DropdownMenuItem(
                  value: category, child: Text(category.toLowerCase())))
              .toList(),
          onChanged: changed);
  Widget controls() => Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Report period'),
                items: const [
                  DropdownMenuItem(value: 'MONTH', child: Text('Monthly')),
                  DropdownMenuItem(value: 'QUARTER', child: Text('Quarterly')),
                  DropdownMenuItem(value: 'YEAR', child: Text('Yearly'))
                ],
                onChanged: busy
                    ? null
                    : (value) {
                        setState(() => period = value!);
                        load();
                      })),
        TextButton(
            onPressed: busy
                ? null
                : () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse('$anchor-01'),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now());
                    if (picked != null) {
                      setState(() =>
                          anchor = picked.toIso8601String().substring(0, 7));
                      load();
                    }
                  },
            child: Text('Month: $anchor')),
        SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: zone,
                decoration: const InputDecoration(labelText: 'Timezone'),
                items: reportZones
                    .map((z) => DropdownMenuItem(
                        value: z,
                        child: Text(z, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) {
                        setState(() {
                          zone = value!;
                          preview = null;
                          selected.clear();
                        });
                        load();
                      }))
      ]);
  List<Widget> overview() {
    if (report == null) {
      return [];
    }
    return [
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final key in ['income', 'spending', 'net'])
          SizedBox(
              width: 160,
              child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(key == 'income'
                                ? 'Received'
                                : key == 'spending'
                                    ? 'Spent'
                                    : 'Net saved'),
                            Text(money(report![key]),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))
                          ]))))
      ]),
      const Text(
          'INR only. Transfers are excluded; net saved is not a bank balance.'),
      if ((report!['transfers'] as num? ?? 0) > 0)
        Text("${money(report!['transfers'])} transfer movements excluded."),
      ...((report!['timeline'] as List? ?? []).cast<Map>()).map((point) => ListTile(
          title: Text("${point['label']}"),
          subtitle: Text(
              "Received ${money(point['income'])}; spent ${money(point['spending'])}"),
          trailing: Text(money(point['net'])))),
      for (final key in ['categories', 'incomeCategories']) ...[
        Text(key == 'categories' ? 'Spending by purpose' : 'Income by source',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...Map<String, dynamic>.from(report![key] as Map? ?? {}).entries.map(
            (entry) => ListTile(
                title: Text(entry.key.toLowerCase()),
                trailing: Text(money(entry.value))))
      ]
    ];
  }

  List<Widget> importControls() => [
        const Divider(height: 32),
        const Text('Upload statement',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text(
            'CSV, Excel (.xlsx) or readable PDF; up to 10 MB. Files are processed privately; only reviewed transactions are saved.'),
        TextField(
            controller: account,
            enabled: !busy,
            maxLength: 100,
            decoration: const InputDecoration(
                labelText: 'Account label',
                hintText: 'Use the same label each time'),
            onChanged: (_) => setState(() {
                  preview = null;
                  selected.clear();
                })),
        DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: order,
            decoration: const InputDecoration(labelText: 'Date format'),
            items: const [
              DropdownMenuItem(value: 'DMY', child: Text('Day / month / year')),
              DropdownMenuItem(value: 'MDY', child: Text('Month / day / year')),
              DropdownMenuItem(value: 'ISO', child: Text('Year / month / day'))
            ],
            onChanged: busy
                ? null
                : (value) => setState(() {
                      order = value!;
                      preview = null;
                      selected.clear();
                    })),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: busy ? null : pickStatement,
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose statement and review'))
      ];
  List<Widget> review() {
    if (preview == null) {
      return [];
    }
    final rows = (preview!['rows'] as List).cast<Map>();
    final eligible = rows.where((row) =>
        row['duplicate'] != true &&
        row['possibleDuplicate'] != true &&
        (row['issues'] as List).isEmpty);
    return [
      ...(preview!['warnings'] as List).map((text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('$text'))),
      CheckboxListTile(
          title: const Text('Select all valid new transactions'),
          value: eligible.isNotEmpty &&
              eligible.every((r) => selected.contains(r['sourceKey'])),
          onChanged: busy
              ? null
              : (value) => setState(() {
                    selected.clear();
                    if (value == true) {
                      selected.addAll(
                          eligible.map((r) => r['sourceKey'] as String));
                    }
                  })),
      ...rows.map((row) {
        final disabled = busy ||
            row['duplicate'] == true ||
            (row['issues'] as List).isNotEmpty;
        return Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                          title: Text("${row['description']}"),
                          subtitle: Text(
                              "${row['occurredAt'] ?? 'Date not read'}; ${row['direction']}; ${money(row['amount'])}${row['duplicate'] == true ? ' ; Already imported' : row['possibleDuplicate'] == true ? ' ; May match SMS/manual entry' : ''}"),
                          value: selected.contains(row['sourceKey']),
                          onChanged: disabled
                              ? null
                              : (value) => setState(() {
                                    if (value == true) {
                                      selected.add(row['sourceKey'] as String);
                                    } else {
                                      selected.remove(row['sourceKey']);
                                    }
                                  })),
                      ...(row['issues'] as List).map((issue) => Text('$issue')),
                      purpose(
                          row['category'] as String,
                          disabled
                              ? null
                              : (value) =>
                                  setState(() => row['category'] = value))
                    ])));
      }),
      FilledButton(
          onPressed: busy || selected.isEmpty ? null : save,
          child: Text('Save ${selected.length} selected transactions'))
    ];
  }

  List<Widget> ledger() {
    if (report == null) {
      return [];
    }
    return [
      const Divider(height: 32),
      const Text('Transactions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ...(report!['transactions'] as List? ?? []).cast<Map>().map((row) => Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "${row['merchant'] ?? row['category']}; ${money(row['amount'])}"),
                    Text("${row['direction']}; ${row['occurredAt']}"),
                    purpose(
                        row['category'] as String,
                        busy
                            ? null
                            : (value) async {
                                setState(() => busy = true);
                                try {
                                  await widget.api
                                      .categorizeFinancialTransaction(
                                          (row['id'] as num).toInt(), value!);
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
                              })
                  ]))))
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Statements & reports'), actions: [
        IconButton(
            tooltip: 'Export CSV',
            onPressed: busy || report == null ? null : export,
            icon: const Icon(Icons.download_outlined))
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (notice != null) Text(notice!),
        controls(),
        const SizedBox(height: 16),
        ...overview(),
        ...importControls(),
        ...review(),
        ...ledger()
      ]));
}
