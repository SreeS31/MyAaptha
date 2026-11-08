import 'package:myaaptha_mobile/core/widgets/info_help.dart';
import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class UploadSettingsScreen extends StatefulWidget {
  const UploadSettingsScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<UploadSettingsScreen> createState() => _UploadSettingsScreenState();
}

class _UploadSettingsScreenState extends State<UploadSettingsScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? usage;
  List<Map<String, dynamic>> levels = [];
  bool admin = false, busy = false, loading = false;
  String? message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) load();
  }

  Future<void> load() async {
    if (loading) {
      return;
    }
    loading = true;
    try {
      final result = await Future.wait([
        widget.api.uploadPolicy(),
        widget.api.sessionProfile(),
      ]);
      final canManage = result[1]['role'] == 'ADMIN';
      final policies = canManage
          ? await widget.api.uploadLevels()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          usage = result[0];
          admin = canManage;
          levels = policies;
          message = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      loading = false;
    }
  }

  Future<void> run(Future<void> Function() action, String success) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      await load();
      if (mounted && message == null) setState(() => message = success);
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editLevel(Map<String, dynamic> level) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: level['name'] as String);
    final storage = TextEditingController(
        text: ((level['storageBytes'] as num) / 1073741824).toString());
    final upload = TextEditingController(
        text: ((level['uploadBytes'] as num) / 1048576).toString());
    final days = TextEditingController(text: '${level['maxRetentionDays']}');
    const never = true;
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, update) {
        Widget number(TextEditingController controller, String label,
                double min, double max, {bool whole = false}) =>
            TextFormField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: label),
                validator: (text) {
                  final value = double.tryParse(text ?? '');
                  return value == null ||
                          !value.isFinite ||
                          value < min ||
                          value > max ||
                          (whole && value != value.roundToDouble())
                      ? 'Choose ${whole ? 'a whole number' : 'a number'} from $min to $max.'
                      : null;
                });
        return AlertDialog(
          title: Text('Level ${level['id']}'),
          content: SingleChildScrollView(
              child: Form(
                  key: form,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(
                        controller: name,
                        maxLength: 50,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter a name.'
                                : null),
                    number(storage, 'Storage (GB)', 0, 100),
                    number(upload, 'Per file (MB)', 1 / 1048576, 25),
                    const Text('Choose an expiry period for each upload, or Never to keep it until you delete it.'),
                  ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  Navigator.pop(context, <String, dynamic>{
                    'id': level['id'],
                    'name': name.text.trim(),
                    'storageBytes':
                        (double.parse(storage.text) * 1073741824).round(),
                    'uploadBytes':
                        (double.parse(upload.text) * 1048576).round(),
                    'maxRetentionDays': double.parse(days.text).toInt(),
                    'allowNever': never,
                  });
                },
                child: const Text('Save level')),
          ],
        );
      }),
    );
    // Dialog route animations may still reference these controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final controller in [name, storage, upload, days]) {
      controller.dispose();
    }
    if (saved != null && mounted) {
      await run(() => widget.api.saveUploadLevel(saved), 'Level saved.');
    }
  }

  Future<void> assignLevel() async {
    final user = TextEditingController();
    final form = GlobalKey<FormState>();
    int selected = levels.first['id'] as int;
    final assignment = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                title: const Text('Assign user level'),
                content: Form(
                    key: form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                          controller: user,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'User ID'),
                          validator: (text) =>
                              (int.tryParse(text ?? '') ?? 0) < 1
                                  ? 'Enter a positive user ID.'
                                  : null),
                      DropdownButtonFormField<int>(
                          initialValue: selected,
                          decoration: const InputDecoration(labelText: 'Level'),
                          items: levels
                              .map((level) => DropdownMenuItem(
                                  value: level['id'] as int,
                                  child: Text(level['name'] as String)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) update(() => selected = value);
                          }),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        if (form.currentState!.validate()) {
                          Navigator.pop(context, {
                            'userId': int.parse(user.text),
                            'levelId': selected
                          });
                        }
                      },
                      child: const Text('Assign level')),
                ],
              )),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    user.dispose();
    if (assignment != null && mounted) {
      await run(
          () => widget.api
              .assignUploadLevel(assignment['userId']!, assignment['levelId']!),
          'User level updated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = usage?['level'] as Map<String, dynamic>?;
    final used = (usage?['usedBytes'] as num? ?? 0).toDouble();
    final limit = (level?['storageBytes'] as num? ?? 0).toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('Storage & uploads'), actions: [
        IconButton(
            tooltip: 'Refresh storage',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh))
      ]),
      body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (level == null && message == null)
                  const Center(child: CircularProgressIndicator()),
                if (level != null) ...[
                  Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    InfoHelpLabel(title:'${level['name']} storage',style:Theme.of(context).textTheme.titleMedium,message:'1 GB free per person, with storage plans up to 100 GB. Choose an expiry period for each upload, or Never to keep it until you delete it. Choose files to delete or upgrade when storage is full. Status attachments expire after one day. Profile photos are limited to 5 MB.'),
                    const SizedBox(height:8),
                    Row(children:[
                      Semantics(label:'Storage used',value:'${(limit>0?used/limit*100:0).toStringAsFixed(1)} percent, ${(used/1073741824).toStringAsFixed(2)} GB used',child:SizedBox.square(dimension:112,child:Stack(alignment:Alignment.center,children:[
                        SizedBox.expand(child:CircularProgressIndicator(value:limit>0?(used/limit).clamp(0.0,1.0):0,strokeWidth:8,backgroundColor:const Color(0xFFE3EDF0),color:const Color(0xFF256F7B))),
                        Text('${(limit>0?used/limit*100:0).toStringAsFixed(1)}%',style:Theme.of(context).textTheme.titleMedium),
                      ]))),
                      const SizedBox(width:16),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text('${(used/1073741824).toStringAsFixed(2)} GB used',style:Theme.of(context).textTheme.titleSmall),
                        Text('of ${(limit/1073741824).toStringAsFixed(2)} GB'),
                        Text('${((limit-used).clamp(0,double.infinity)/1073741824).toStringAsFixed(2)} GB free'),
                      ])),
                    ]),
                    const Divider(height:20),
                    Text('Up to ${((level['uploadBytes'] as num)/1048576).toStringAsFixed(1)} MB per file.'),
                  ]))),
                  const SizedBox(height:8),
                ],
                if (admin)
                  ExpansionTile(
                      title: const Text('Manage user levels'),
                      children: [
                        const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                                '1 GB free per person, with storage plans up to 100 GB. Choose an expiry period for each upload, or Never to keep it until you delete it. Reducing a quota preserves existing files and blocks uploads over the limit. Users choose what to delete. These settings do not charge users.')),
                        for (final policy in levels)
                          ListTile(
                              title: Text(
                                  'Level ${policy['id']}: ${policy['name']}'),
                              trailing: const Icon(Icons.edit),
                              onTap: busy ? null : () => editLevel(policy)),
                        if (levels.length < 5)
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => editLevel({
                                        'id': [1, 2, 3, 4, 5].firstWhere((id) =>
                                            levels.every(
                                                (level) => level['id'] != id)),
                                        'name': 'Premium ${levels.length}',
                                        'storageBytes': 10737418240,
                                        'uploadBytes': 26214400,
                                        'maxRetentionDays': 36500,
                                        'allowNever': true
                                      }),
                              child: const Text('Add level')),
                        if (levels.isNotEmpty)
                          TextButton(
                              onPressed: busy ? null : assignLevel,
                              child: const Text('Assign user level')),
                      ]),
                if (busy) const LinearProgressIndicator(),
                if (message != null)
                  Semantics(liveRegion: true, child: Text(message!)),
              ])),
    );
  }
}
