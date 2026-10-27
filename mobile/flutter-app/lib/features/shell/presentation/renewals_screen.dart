import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/core/platform/attachment_opener.dart';
import 'package:myaaptha_mobile/core/widgets/info_help.dart';

class RenewalsScreen extends StatefulWidget {
  const RenewalsScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<RenewalsScreen> createState() => _RenewalsScreenState();
}

class _RenewalsScreenState extends State<RenewalsScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> items = [];
  bool loading = true, refreshing = false;
  String? error;
  String filter = 'active', query = '';
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (ModalRoute.of(context)?.isCurrent == true) load();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final rows = await widget.api.renewals();
      if (mounted) {
        setState(() {
          items = rows;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      refreshing = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([Map<String, dynamic>? item, bool renew = false]) async {
    await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            RenewalEditor(api: widget.api, item: item, renew: renew));
    await load();
  }

  Future<void> archive(Map<String, dynamic> item) async {
    try {
      await widget.api.setRenewalState(item['id'] as int,
          archived: item['archived'] != true);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete this item?'),
                content: Text(
                    '${item['title']} and its receipt will be removed. Future reminders will stop.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete item'))
                ]));
    if (confirmed != true) return;
    try {
      await widget.api.deleteRenewal(item['id'] as int);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> receipt(Map<String, dynamic> item) async {
    try {
      final bytes =
          await widget.api.attachment(item['attachmentUrl'] as String);
      final opened = await openAttachmentBytes(bytes,
          item['attachmentType'] as String, item['attachmentName'] as String);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No application could open this receipt.')));
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  String status(Map<String, dynamic> item) {
    final days = item['daysRemaining'] as int;
    return item['archived'] == true
        ? 'Archived'
        : days < 0
            ? 'Expired ${days.abs()}d ago'
            : days == 0
                ? 'Due today'
                : '$days days left';
  }

  @override
  Widget build(BuildContext context) {
    final visible = items.where((item) {
      final archived = item['archived'] == true,
          days = item['daysRemaining'] as int;
      return (filter == 'archived'
              ? archived
              : !archived &&
                  (filter != 'soon' || days >= 0 && days <= 30) &&
                  (filter != 'expired' || days < 0)) &&
          '${item['title']} ${item['provider']} ${item['referenceNumber']}'
              .toLowerCase()
              .contains(query.toLowerCase());
    }).toList();
    return Scaffold(
        appBar: AppBar(title: const Text('Bills & warranties'), actions: const [
          InfoHelp(
              title: 'Renewal reminders',
              message:
                  'Reminders are created at 9am in the selected time zone, 30, 15, 7, 3 and 1 day before expiry. Email, SMS and push follow your notification settings and configured providers. Missed dates are skipped. Renewing an item does not record a payment.')
        ]),
        body: RefreshIndicator(
            onRefresh: load,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              FilledButton.icon(
                  onPressed: () => edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add bill or warranty')),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 8, children: [
                Chip(
                    label: Text(
                        '${items.where((x) => x['archived'] != true && (x['daysRemaining'] as int) >= 0 && (x['daysRemaining'] as int) <= 30).length} due within 30 days')),
                const Chip(label: Text('30 / 15 / 7 / 3 / 1 days'))
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  initialValue: filter,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Show'),
                  items: const [
                    DropdownMenuItem(
                        value: 'active', child: Text('All current items')),
                    DropdownMenuItem(
                        value: 'soon', child: Text('Due within 30 days')),
                    DropdownMenuItem(value: 'expired', child: Text('Expired')),
                    DropdownMenuItem(value: 'archived', child: Text('Archived'))
                  ],
                  onChanged: (value) => setState(() => filter = value!)),
              const SizedBox(height: 12),
              TextField(
                  decoration: const InputDecoration(
                      labelText: 'Search bills and warranties',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (value) => setState(() => query = value)),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              if (loading)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator())),
              if (!loading && visible.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(children: [
                      Icon(Icons.event_available_outlined, size: 44),
                      SizedBox(height: 12),
                      Text('Your next renewal, remembered'),
                      SizedBox(height: 8),
                      Text('Add an item or change the filter.')
                    ])),
              ...visible.map((item) {
                final days = item['daysRemaining'] as int;
                final color = days < 0
                    ? Colors.red.shade700
                    : days <= 30
                        ? Colors.brown.shade700
                        : Theme.of(context).colorScheme.primary;
                return Card(
                    margin: const EdgeInsets.only(top: 16),
                    child: Container(
                        decoration: BoxDecoration(
                            border:
                                Border(top: BorderSide(color: color, width: 3)),
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 12,
                                  runSpacing: 6,
                                  children: [
                                    Text(item['kind'] == 'BILL'
                                        ? 'Bill'
                                        : item['kind'] == 'WARRANTY'
                                            ? 'Warranty'
                                            : 'Service plan'),
                                    Text(status(item),
                                        style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w600))
                                  ]),
                              const SizedBox(height: 10),
                              Text('${item['title']}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              if ((item['provider']?.toString() ?? '')
                                  .isNotEmpty)
                                Text('${item['provider']}'),
                              const SizedBox(height: 10),
                              Text(
                                  '${item['kind'] == 'BILL' ? 'Due' : 'Expires'}: ${item['expiresOn']}'),
                              if (item['amount'] != null)
                                Text('INR ${item['amount']}'),
                              if ((item['referenceNumber']?.toString() ?? '')
                                  .isNotEmpty)
                                Text('Reference: ${item['referenceNumber']}'),
                              const SizedBox(height: 8),
                              Text(
                                  item['archived'] == true
                                      ? 'Reminders stopped'
                                      : item['remindersEnabled'] != true
                                          ? 'Reminders paused'
                                          : item['nextReminderAt'] == null
                                              ? 'No reminders remaining'
                                              : 'Reminders on / ${item['timezone']}',
                                  style: Theme.of(context).textTheme.bodySmall),
                              if ((item['notes']?.toString() ?? '').isNotEmpty)
                                ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: const Text('Notes'),
                                    children: [
                                      Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text('${item['notes']}'))
                                    ]),
                              if (item['attachmentUrl'] != null)
                                TextButton.icon(
                                    onPressed: () => receipt(item),
                                    icon:
                                        const Icon(Icons.receipt_long_outlined),
                                    label: Text(
                                        'Receipt: ${item['attachmentName']}')),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                OutlinedButton(
                                    onPressed: () => edit(item),
                                    child: const Text('Edit')),
                                FilledButton.tonal(
                                    onPressed: () => edit(item, true),
                                    child: const Text('Renew')),
                                TextButton(
                                    onPressed: () => archive(item),
                                    child: Text(item['archived'] == true
                                        ? 'Restore'
                                        : 'Archive')),
                                TextButton(
                                    onPressed: () => remove(item),
                                    child: const Text('Delete'))
                              ])
                            ])));
              }),
              const SizedBox(height: 24)
            ])));
  }
}

class RenewalEditor extends StatefulWidget {
  const RenewalEditor(
      {super.key, required this.api, this.item, this.renew = false});
  final MyAapthaApi api;
  final Map<String, dynamic>? item;
  final bool renew;
  @override
  State<RenewalEditor> createState() => _RenewalEditorState();
}

class _RenewalEditorState extends State<RenewalEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title,
      provider,
      reference,
      amount,
      purchased,
      expires,
      notes;
  late String kind, zone;
  late bool reminders;
  bool busy = false, removeReceipt = false;
  String? error;
  int? id;
  PlatformFile? file;
  static const zones = [
    'Asia/Kolkata',
    'UTC',
    'Asia/Dubai',
    'Asia/Singapore',
    'Europe/London',
    'America/New_York',
    'America/Los_Angeles',
    'Australia/Sydney'
  ];
  @override
  void initState() {
    super.initState();
    final item = widget.item ?? {};
    id = item['id'] as int?;
    title = TextEditingController(text: item['title'] as String?);
    provider = TextEditingController(text: item['provider'] as String?);
    reference = TextEditingController(text: item['referenceNumber'] as String?);
    amount = TextEditingController(text: item['amount']?.toString());
    purchased = TextEditingController(text: item['purchasedOn'] as String?);
    expires = TextEditingController(
        text: widget.renew ? '' : item['expiresOn'] as String?);
    notes = TextEditingController(text: item['notes'] as String?);
    kind = item['kind'] as String? ?? 'BILL';
    zone = item['timezone'] as String? ?? 'Asia/Kolkata';
    reminders = item['remindersEnabled'] != false;
  }

  @override
  void dispose() {
    for (final controller in [
      title,
      provider,
      reference,
      amount,
      purchased,
      expires,
      notes
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> pickDate(TextEditingController controller) async {
    final chosen = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(9999, 12, 31));
    if (chosen != null) {
      controller.text =
          '${chosen.year.toString().padLeft(4, '0')}-${chosen.month.toString().padLeft(2, '0')}-${chosen.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> pickReceipt() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
          withData: true);
      if (result == null || !mounted) return;
      final selected = result.files.single;
      if (selected.bytes == null ||
          selected.size == 0 ||
          selected.size > 25 * 1024 * 1024) {
        throw const FormatException(
            'Choose a readable receipt of 25 MB or smaller.');
      }
      setState(() {
        file = selected;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    bool detailsSaved = false;
    try {
      final saved = await widget.api.saveRenewal({
        'kind': kind,
        'title': title.text.trim(),
        'provider': provider.text.trim(),
        'referenceNumber': reference.text.trim(),
        'amount': amount.text.isEmpty ? null : num.parse(amount.text),
        'purchasedOn': purchased.text.isEmpty ? null : purchased.text,
        'expiresOn': expires.text,
        'timezone': zone,
        'notes': notes.text,
        'remindersEnabled': reminders,
        'archived': widget.renew ? false : widget.item?['archived'] == true
      }, id: id);
      id = saved['id'] as int;
      detailsSaved = true;
      if (file != null) {
        await widget.api.attachRenewalReceipt(id!, file!.bytes!, file!.name);
      } else if (removeReceipt) {
        await widget.api.removeRenewalReceipt(id!);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error =
            '${detailsSaved ? 'Details saved; receipt update failed. Retry or cancel to keep the saved details. ' : ''}$e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: AlertDialog(
          title: Text(widget.renew
              ? 'Renew item'
              : widget.item == null
                  ? 'Add bill or warranty'
                  : 'Edit bill or warranty'),
          content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                  child: Form(
                      key: form,
                      child: AbsorbPointer(
                          absorbing: busy,
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (error != null)
                                  Text(error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                                DropdownButtonFormField<String>(
                                    initialValue: kind,
                                    decoration: const InputDecoration(
                                        labelText: 'Item type'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'BILL', child: Text('Bill')),
                                      DropdownMenuItem(
                                          value: 'WARRANTY',
                                          child: Text('Warranty')),
                                      DropdownMenuItem(
                                          value: 'SERVICE',
                                          child: Text('Service plan'))
                                    ],
                                    onChanged: (value) =>
                                        setState(() => kind = value!)),
                                TextFormField(
                                    controller: title,
                                    maxLength: 160,
                                    decoration: const InputDecoration(
                                        labelText: 'Title'),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Enter a title'
                                            : null),
                                TextFormField(
                                    controller: provider,
                                    maxLength: 160,
                                    decoration: const InputDecoration(
                                        labelText: 'Provider or store')),
                                TextFormField(
                                    controller: reference,
                                    maxLength: 160,
                                    decoration: const InputDecoration(
                                        labelText:
                                            'Invoice or reference number')),
                                TextFormField(
                                    controller: amount,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Amount (INR, optional)'),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return null;
                                      }
                                      final number = num.tryParse(value);
                                      return number == null ||
                                              number < 0 ||
                                              number > 1000000000000 ||
                                              !RegExp(r'^\d+(\.\d{1,2})?$')
                                                  .hasMatch(value)
                                          ? 'Enter a valid amount with up to 2 decimals'
                                          : null;
                                    }),
                                TextFormField(
                                    controller: purchased,
                                    readOnly: true,
                                    onTap: () => pickDate(purchased),
                                    decoration: InputDecoration(
                                        labelText: 'Purchase or start date',
                                        suffixIcon: IconButton(
                                            tooltip: 'Clear purchase date',
                                            onPressed: () => purchased.clear(),
                                            icon: const Icon(Icons.clear)))),
                                TextFormField(
                                    controller: expires,
                                    readOnly: true,
                                    onTap: () => pickDate(expires),
                                    decoration: InputDecoration(
                                        labelText: kind == 'BILL'
                                            ? 'Due date'
                                            : 'Expiry date',
                                        suffixIcon: const Icon(
                                            Icons.calendar_today_outlined)),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Choose a date';
                                      }
                                      return purchased.text.isNotEmpty &&
                                              purchased.text.compareTo(value) >
                                                  0
                                          ? 'Expiry must be after purchase'
                                          : null;
                                    }),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                    initialValue: zone,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Reminder time zone'),
                                    items: {zone, ...zones}
                                        .map((value) => DropdownMenuItem(
                                            value: value, child: Text(value)))
                                        .toList(),
                                    onChanged: (value) =>
                                        setState(() => zone = value!)),
                                TextFormField(
                                    controller: notes,
                                    maxLines: 2,
                                    maxLength: 2000,
                                    decoration: const InputDecoration(
                                        labelText: 'Notes')),
                                SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title:
                                        const Text('Remind me before expiry'),
                                    subtitle: const Text(
                                        '30, 15, 7, 3 and 1 day before'),
                                    value: reminders,
                                    onChanged: (value) =>
                                        setState(() => reminders = value)),
                                OutlinedButton.icon(
                                    onPressed: pickReceipt,
                                    icon: const Icon(Icons.attach_file),
                                    label: Text(file?.name ??
                                        'Attach receipt (optional)')),
                                if (file != null)
                                  TextButton(
                                      onPressed: () =>
                                          setState(() => file = null),
                                      child:
                                          const Text('Remove selected file')),
                                const Text(
                                    'PDF, JPG, PNG or WebP. Account upload limit applies, maximum 25 MB.'),
                                if (widget.item?['attachmentName'] != null)
                                  CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                          'Remove current receipt: ${widget.item!['attachmentName']}'),
                                      value: removeReceipt,
                                      onChanged: (value) => setState(
                                          () => removeReceipt = value == true)),
                              ]))))),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy
                    ? 'Saving...'
                    : widget.renew
                        ? 'Save renewal'
                        : 'Save item'))
          ]));
}
