import 'package:myaaptha_mobile/core/contacts/contact_oauth_poll.dart';
import 'package:myaaptha_mobile/core/contacts/device_contact_access.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myaaptha_mobile/core/contacts/contact_import.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen(
      {super.key, required this.api, this.readDeviceContacts});
  final MyAapthaApi api;
  final Future<List<Map<String, dynamic>>> Function()? readDeviceContacts;
  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  final email = TextEditingController(), search = TextEditingController();
  List<Map<String, dynamic>> items = [], circles = [];
  Map<String, dynamic> providers = {};
  bool busy = false, organize = true, cancelled = false;
  String? error, message;
  int total = 0, processed = 0;
  int? cursor, circleFilter;
  String activeQuery = '';
  int loadVersion = 0;
  @override
  void initState() {
    super.initState();
    load();
    widget.api.addressBookProviders().then((v) {
      if (mounted) setState(() => providers = v);
    }).catchError((Object e) {
      if (mounted) setState(() => error = '$e');
    });
  }

  @override
  void dispose() {
    cancelled = true;
    email.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> load({int after = 0}) async {
    final version = ++loadVersion;
    try {
      final page = await widget.api.addressBook(
          query: activeQuery, afterId: after, circleId: circleFilter);
      final groups = await widget.api.addressCircles();
      if (!mounted || version != loadVersion) return;
      setState(() {
        final next = (page['items'] as List)
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
        items = after == 0 ? next : [...items, ...next];
        total = (page['total'] as num).toInt();
        cursor = (page['nextCursor'] as num?)?.toInt();
        circles = groups;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> run(Future<void> Function() work) async {
    setState(() {
      busy = true;
      error = null;
      cancelled = false;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String title, String text,
          {String action = 'Confirm'}) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) =>
              AlertDialog(title: Text(title), content: Text(text), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(action))
              ])) ??
      false;
  Future<List<Map<String, dynamic>>> deviceContacts() async {
    if (widget.readDeviceContacts != null) return widget.readDeviceContacts!();
    final contacts = await readPermittedDeviceContacts(isActive: () => mounted);
    return contacts
        .map((c) => {
              'displayName': c.displayName.trim().isNotEmpty
                  ? c.displayName
                  : c.phones.firstOrNull?.number ??
                      c.emails.firstOrNull?.address ??
                      'Unnamed contact',
              'phones': c.phones
                  .map((p) => p.number)
                  .where((s) => s.trim().isNotEmpty)
                  .toList(),
              'emails': c.emails
                  .map((e) => e.address)
                  .where((s) => s.trim().isNotEmpty)
                  .toList(),
              'organization': c.organization?.company ?? '',
              'groups': <String>[]
            })
        .toList();
  }

  Future<void> save(List<Map<String, dynamic>> contacts, String source) async {
    if (contacts.isEmpty) {
      setState(() => message =
          'No contacts are available. On iOS, only contacts allowed by your permission are included.');
      return;
    }
    final prepared=prepareContactReview(contacts,circles.map((c)=>'${c['name']}').toList());
    final skipped=contacts.length-prepared.length;
    if(prepared.isEmpty){setState(()=>message='Skipped $skipped contacts without a usable phone number.');return;}
    final accepted=await showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,update)=>AlertDialog(
      title:const Text('Review contacts'),
      content:SizedBox(width:560,height:440,child:Column(children:[
        Text('Skipped $skipped without a usable phone number. Nothing is saved until you submit.'),
        CheckboxListTile(title:const Text('Select all'),value:prepared.every((r)=>r['selected']==true),onChanged:(v)=>update((){for(final r in prepared){r['selected']=v??false;}})),
        Expanded(child:ListView.builder(itemCount:prepared.length,itemBuilder:(context,index){final row=prepared[index];return Padding(padding:const EdgeInsets.only(bottom:12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          CheckboxListTile(contentPadding:EdgeInsets.zero,title:Text('${row['displayName']}'),subtitle:Text([...(row['phones'] as List),...(row['emails'] as List)].join(' | ')),value:row['selected']==true,onChanged:(v)=>update(()=>row['selected']=v??false)),
          if(organize) TextFormField(key:ValueKey(index),initialValue:(row['circleNames'] as List).join('; '),maxLength:2000,decoration:const InputDecoration(labelText:'Circles (separate with semicolons)',counterText:''),onChanged:(value)=>row['circleNames']=value.split(';').map((n)=>n.trim()).where((n)=>n.isNotEmpty).take(20).toList())
        ]));}))
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),FilledButton(onPressed:prepared.any((r)=>r['selected']==true)?()=>Navigator.pop(dialogContext,true):null,child:const Text('Import selected'))]
    )));
    if(accepted!=true)return;
    contacts=prepared.where((r)=>r['selected']==true).toList();
    if (!mounted) return;
    setState(() => processed = 0);
    try {
      final result = await importContactBatches(contacts,
          (batch) => widget.api.importReviewedAddressBook(batch, source, organize),
          (done) {
        if (mounted) setState(() => processed = done);
      }, () => cancelled || !mounted);
      if (mounted) {
        setState(() => message =
            '${result['added']} added, ${result['updated']} updated, ${result['unchanged']} duplicates unchanged. ${result['organizationMessage']} ${cancelled ? 'Stopped after the current batch. Reimport to continue.' : ''}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => message =
            'Import stopped after $processed contacts. Completed batches are saved. Retry safely; exact duplicates are not added again.');
      }
      rethrow;
    } finally {
      if (mounted) await load();
    }
  }

  Future<void> chooseFile() async {
    final files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'vcf'],
        withData: true);
    if (files == null || !mounted) return;
    final file = files.files.single;
    if (file.size > 20 * 1024 * 1024) {
      throw const FormatException('Choose an export smaller than 20 MB.');
    }
    if (file.bytes == null) {
      throw const FormatException('The file could not be read.');
    }
    final text = utf8.decode(file.bytes!);
    final vcard = file.name.toLowerCase().endsWith('.vcf');
    await save(vcard ? parseContactVcard(text) : parseContactCsv(text),
        vcard ? 'vcard' : 'csv');
  }

  Future<void> connect(String provider) async {
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email.text.trim())) {
      throw const FormatException('Enter a valid email address.');
    }
    if (!await confirm('Import email contacts?',
        'Sign in with ${provider == 'google' ? 'Google' : 'Microsoft'} and approve read-only contacts access. Review contacts and circle suggestions before saving. ',
        action: 'Continue')) {
      return;
    }
    final started = await widget.api
        .connectAddressBook(email.text.trim(), provider, organize);
    if (!await launchUrl(Uri.parse(started['authorizationUrl'].toString()),
        mode: LaunchMode.externalApplication)) {
      throw const MyAapthaApiException(
          'Could not open the provider sign-in page.');
    }
    if (mounted) {
      setState(() => message =
          'Approve access in the provider sign-in page, then return here.');
    }
    try {
      final result = await waitForContactOAuth(
        () => widget.api.addressBookOAuthResult(started['resultKey'].toString()),
        isActive: () => mounted && !cancelled, attempts: 300);
      if (!mounted || cancelled) return;
      if (result['contacts'] is List) {
        await save((result['contacts'] as List).map((r) => Map<String,dynamic>.from(r as Map)).toList(), provider);
      } else { setState(() => message = '${result['message']}'); }
    } on ContactOAuthCancelled {
      return;
    }
  }

  Future<void> editCircles(Map<String, dynamic> contact) async {
    final selected = Set<int>.from(
        (contact['circleIds'] as List? ?? []).map((v) => (v as num).toInt()));
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    title: Text('Circles for ${contact['displayName']}'),
                    content: SizedBox(
                        width: 400,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              const Text(
                                  'Private assignments only. Reimports preserve your manual choices.'),
                              for (final c in circles)
                                CheckboxListTile(
                                    title: Text('${c['name']}'),
                                    value: selected.contains(c['id']),
                                    onChanged: (value) => update(() {
                                          if (value == true) {
                                            selected.add(c['id'] as int);
                                          } else {
                                            selected.remove(c['id']);
                                          }
                                        })),
                              if (circles.isEmpty)
                                const Text(
                                    'Create a circle from My circles, then refresh.')
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save circles'))
                    ])));
    if (accepted == true && mounted) {
      await run(() async {
        await widget.api
            .assignAddressCircles(contact['id'] as int, selected.toList());
        await load();
      });
    }
  }

  Future<void> relate(Map<String, dynamic> contact) async {
    final phones = List<String>.from(contact['phones'] as List? ?? []);
    var type = 'Other';
    String? phone = phones.firstOrNull;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    title: Text('Add ${contact['displayName']} as a relation?'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'This creates a separate relationship. Existing members may receive a relationship notification.'),
                      DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration:
                              const InputDecoration(labelText: 'Relationship'),
                          items: [
                            'Other',
                            'Friend',
                            'Relative',
                            'Colleague',
                            'Mother',
                            'Father',
                            'Brother',
                            'Sister',
                            'Son',
                            'Daughter',
                            'Cousin'
                          ]
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) => update(() => type = v!)),
                      if (phones.isNotEmpty)
                        DropdownButtonFormField<String>(
                            initialValue: phone,
                            decoration: const InputDecoration(
                                labelText: 'Phone number'),
                            items: phones
                                .map((v) =>
                                    DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) => update(() => phone = v))
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Confirm relation'))
                    ])));
    if (accepted == true && mounted) {
      await run(() async {
        await widget.api
            .relateAddressContact(contact['id'] as int, type, phone);
        await load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('My contacts'), actions: [
        IconButton(
            tooltip: 'Refresh contacts',
            onPressed: busy ? null : () => load(),
            icon: const Icon(Icons.refresh))
      ]),
      body: SafeArea(
          child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('PRIVATE ADDRESS BOOK',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        const Text(
                            'Review the contacts allowed by your device permission before importing. Saved contacts stay private and are available on web and mobile.'),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Suggest circles for review'),
                            subtitle: const Text(
                                'Uses explicit labels, organizations and matching name text. Review and edit circles before saving.'),
                            value: organize,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => organize = v)),
                        FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () => run(() async {
                                      final contacts = await deviceContacts();
                                      if (mounted) {
                                        await save(contacts, 'device');
                                      }
                                    }),
                            icon: const Icon(Icons.contacts_outlined),
                            label: const Text('Import all device contacts')),
                        OutlinedButton(
                            onPressed: busy ? null : () => run(chooseFile),
                            child: const Text('Import CSV or vCard')),
                        if (!kIsWeb)
                          TextButton(
                              onPressed: busy ? null : () => openAppSettings(),
                              child: const Text('Contact permission settings')),
                        TextField(
                            controller: email,
                            enabled: !busy,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                                labelText: 'Google or Outlook email')),
                        Wrap(spacing: 8, children: [
                          OutlinedButton(
                              onPressed: busy || providers['google'] != true
                                  ? null
                                  : () => run(() => connect('google')),
                              child: const Text('Import Google Contacts')),
                          OutlinedButton(
                              onPressed: busy || providers['microsoft'] != true
                                  ? null
                                  : () => run(() => connect('microsoft')),
                              child: const Text('Import Outlook Contacts'))
                        ]),
                        if (providers['google'] != true ||
                            providers['microsoft'] != true)
                          const Text(
                              'Unavailable email providers need administrator setup. Device and file imports work without provider setup or an AI key.'),
                        if (busy) ...[
                          const LinearProgressIndicator(),
                          Text('Processed $processed contacts'),
                          TextButton(
                              onPressed: () => setState(() => cancelled = true),
                              child: const Text(
                                  'Stop after current batch / stop waiting'))
                        ],
                        if (error != null)
                          Text(error!,
                              style: const TextStyle(color: Colors.red)),
                        if (message != null)
                          Text(message!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 20),
                        Text('$total saved contacts',
                            style: Theme.of(context).textTheme.titleLarge),
                        TextField(
                            controller: search,
                            enabled: !busy,
                            decoration: InputDecoration(
                                labelText: 'Search by name',
                                suffixIcon: IconButton(
                                    tooltip: 'Search contacts',
                                    onPressed: busy
                                        ? null
                                        : () {
                                            activeQuery = search.text;
                                            load();
                                          },
                                    icon: const Icon(Icons.search))),
                            onSubmitted: (_) {
                              activeQuery = search.text;
                              load();
                            }),
                        DropdownButtonFormField<int>(
                            initialValue: circleFilter ?? 0,
                            decoration: const InputDecoration(
                                labelText: 'Filter by circle'),
                            items: [
                              const DropdownMenuItem(
                                  value: 0,
                                  child: Text('All private contacts')),
                              for (final c in circles)
                                DropdownMenuItem(
                                    value: c['id'] as int,
                                    child: Text(
                                        '${c['name']} (${c['privateContactCount']})',
                                        overflow: TextOverflow.ellipsis))
                            ],
                            isExpanded: true,
                            onChanged: busy
                                ? null
                                : (id) {
                                    setState(() =>
                                        circleFilter = id == 0 ? null : id);
                                    load();
                                  }),
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                                'Private circle lists do not grant access to messages. Exact repeat imports are deduplicated; changed names or contact details can create new entries.'))
                      ]);
                }
                if (index == items.length + 1) {
                  return Column(children: [
                    if (items.isEmpty)
                      const Text(
                          'No contacts found. Import a list or clear the search.'),
                    if (cursor != null)
                      OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => run(() => load(after: cursor!)),
                          child: const Text('Load more contacts')),
                    if (total > 0)
                      TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  if (await confirm(
                                          'Clear private address book?',
                                          'This removes saved MyAaptha contacts. Your phone/provider contacts, circles and relations remain.',
                                          action: 'Clear all') &&
                                      mounted) {
                                    await run(() async {
                                      await widget.api.clearAddressBook();
                                      await load();
                                    });
                                  }
                                },
                          child: const Text('Clear private address book'))
                  ]);
                }
                final c = items[index - 1];
                final phones = List<String>.from(c['phones'] as List),
                    emails = List<String>.from(c['emails'] as List);
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${c['displayName']}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              if ('${c['organization'] ?? ''}'.isNotEmpty)
                                Text('${c['organization']}'),
                              for (final value in [...phones, ...emails])
                                Text(value),
                              Wrap(spacing: 8, children: [
                                TextButton(
                                    onPressed:
                                        busy ? null : () => editCircles(c),
                                    child: const Text('Edit circles')),
                                if (c['relationshipId'] != null)
                                  const Text('Added as a relation')
                                else
                                  TextButton(
                                      onPressed: busy ||
                                              (phones.isEmpty && emails.isEmpty)
                                          ? null
                                          : () => relate(c),
                                      child: const Text('Add as relation')),
                                TextButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            if (await confirm(
                                                    'Remove ${c['displayName']}?',
                                                    'Remove only this private contact? Device contacts and relations remain.',
                                                    action: 'Remove') &&
                                                mounted) {
                                              await run(() async {
                                                await widget.api
                                                    .removeAddressContact(
                                                        c['id'] as int);
                                                await load();
                                              });
                                            }
                                          },
                                    child: const Text('Remove'))
                              ])
                            ])));
              })));
}
