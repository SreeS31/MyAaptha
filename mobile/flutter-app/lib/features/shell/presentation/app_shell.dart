import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';

import 'package:circlenet_mobile/core/models/network_models.dart';
import 'package:circlenet_mobile/core/network/circlenet_api.dart';
import 'package:circlenet_mobile/core/platform/attachment_opener.dart';
import 'package:circlenet_mobile/core/theme/app_theme.dart';
import 'package:circlenet_mobile/features/auth/data/session_store.dart';
import 'package:circlenet_mobile/features/auth/models/auth_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session, required this.onSignedOut});
  final AuthTokenBundle session;
  final VoidCallback onSignedOut;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  late final CircleNetApi api = CircleNetApi(widget.session);
  Timer? incomingTimer;
  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
  bool showingIncomingCall = false;
  int unreadNotifications = 0;
  int unreadMessages = 0;
  int unreadCircleMessages = 0;
  int syncVersion = 0;
  List<Widget> get pages => <Widget>[
        NetworkHome(key: ValueKey('network-$syncVersion'), api: api),
        SocialFeedScreen(key: ValueKey('feed-$syncVersion'), api: api),
        MessagesScreen(key: ValueKey('messages-$syncVersion'), api: api),
        CirclesScreen(key: ValueKey('circles-$syncVersion'), api: api),
        NotificationsScreen(
            key: ValueKey('notifications-$syncVersion'), api: api),
        DiscoverScreen(api: api),
        ProfileScreen(
            key: ValueKey('profile-$syncVersion'),
            api: api,
            onDataChanged: () {
              if (mounted) setState(() => syncVersion++);
            }),
        MoreScreen(
            api: api,
            session: widget.session,
            onSignOut: signOut,
            onSelectPrimaryPage: (value) => setState(() => index = value))
      ];
  static const mobileDestinationIndexes = <int>[0, 1, 2, 3, 7];
  List<NavigationDestination> get destinations => [
        const NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree_rounded),
            label: 'Network'),
        const NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed_rounded),
            label: 'Feed'),
        NavigationDestination(
            icon: Badge(
                isLabelVisible: unreadMessages > 0,
                label: Text(unreadMessages > 99 ? '99+' : '$unreadMessages'),
                child: const Icon(Icons.chat_bubble_outline_rounded)),
            selectedIcon: Badge(
                isLabelVisible: unreadMessages > 0,
                label: Text(unreadMessages > 99 ? '99+' : '$unreadMessages'),
                child: const Icon(Icons.chat_bubble_rounded)),
            label: 'Messages'),
        NavigationDestination(
            icon: Badge(
                isLabelVisible: unreadCircleMessages > 0,
                label: Text(unreadCircleMessages > 99
                    ? '99+'
                    : '$unreadCircleMessages'),
                child: const Icon(Icons.forum_outlined)),
            selectedIcon: Badge(
                isLabelVisible: unreadCircleMessages > 0,
                label: Text(unreadCircleMessages > 99
                    ? '99+'
                    : '$unreadCircleMessages'),
                child: const Icon(Icons.forum_rounded)),
            label: 'Circles'),
        NavigationDestination(
            icon: Badge(
                isLabelVisible: unreadNotifications > 0,
                label: Text(
                    unreadNotifications > 99 ? '99+' : '$unreadNotifications'),
                child: const Icon(Icons.notifications_outlined)),
            selectedIcon: Badge(
                isLabelVisible: unreadNotifications > 0,
                label: Text(
                    unreadNotifications > 99 ? '99+' : '$unreadNotifications'),
                child: const Icon(Icons.notifications_rounded)),
            label: 'Alerts'),
        const NavigationDestination(
            icon: Icon(Icons.person_search_outlined),
            selectedIcon: Icon(Icons.person_search_rounded),
            label: 'Discover'),
        const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile'),
        const NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded),
            label: 'More')
      ];
  @override
  void initState() {
    super.initState();
    incomingTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => checkIncomingCalls());
    connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (mounted &&
          results.any((result) => result != ConnectivityResult.none)) {
        setState(() => syncVersion++);
        checkIncomingCalls();
      }
    });
    Future<void>.delayed(Duration.zero, checkIncomingCalls);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => maybeSuggestContactOrganizer());
  }

  @override
  void dispose() {
    incomingTimer?.cancel();
    connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> checkIncomingCalls() async {
    if (!mounted) return;
    try {
      await api.heartbeatPresence();
    } catch (_) {}
    try {
      final count = await api.unreadNotificationCount();
      if (mounted && count != unreadNotifications) {
        setState(() => unreadNotifications = count);
      }
    } catch (_) {}
    try {
      final conversations = await api.directConversations();
      final count =
          conversations.fold<int>(0, (sum, item) => sum + item.unreadCount);
      if (mounted && count != unreadMessages) {
        setState(() => unreadMessages = count);
      }
    } catch (_) {}
    try {
      final counts = await api.circleUnreadCounts();
      final count = counts.values.fold<int>(0, (sum, value) => sum + value);
      if (mounted && count != unreadCircleMessages) {
        setState(() => unreadCircleMessages = count);
      }
    } catch (_) {}
    if (showingIncomingCall) return;
    try {
      final calls = await api.incomingCalls();
      if (!mounted || calls.isEmpty) return;
      showingIncomingCall = true;
      final call = calls.first;
      final accept = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                  icon: Icon(
                      call.callType == 'VIDEO'
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      color: AppTheme.primary,
                      size: 38),
                  title: Text(call.callerName),
                  content: Text('Incoming ${call.callType.toLowerCase()} call'),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    FilledButton.tonal(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Decline')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Accept'))
                  ]));
      if (accept == true && mounted) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    DirectCallScreen(api: api, incomingCall: call)));
      } else if (accept == false) {
        await api.rejectCall(call.id);
      }
    } catch (_) {
      // Polling stays silent; the next cycle retries automatically.
    } finally {
      showingIncomingCall = false;
    }
  }

  Future<void> maybeSuggestContactOrganizer() async {
    if (!mounted || kIsWeb) return;
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool('contact_organizer_prompted') == true || !mounted) {
      return;
    }
    await preferences.setBool('contact_organizer_prompted', true);
    if (!mounted) return;
    final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              icon: const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.primary, size: 38),
              title: const Text('Organize your contacts?'),
              content: const Text(
                  'This optional step can suggest family relationships and circles after you grant contact permission. You review everything before it is added.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Later')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Review contacts')),
              ],
            ));
    if (open == true && mounted) {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => ContactOrganizerScreen(api: api)));
      if (mounted) setState(() => syncVersion++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final content = IndexedStack(index: index, children: pages);
    return Scaffold(
      body: SafeArea(
        child: wide
            ? Row(children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (value) =>
                      setState(() => index = value),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: _BrandMark(),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: IconButton(
                        tooltip: 'Sign out',
                        onPressed: signOut,
                        icon: const Icon(Icons.logout_rounded),
                      ),
                    ),
                  ),
                  destinations: destinations
                      .map((item) => NavigationRailDestination(
                            icon: item.icon,
                            selectedIcon: item.selectedIcon,
                            label: Text(item.label),
                          ))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ])
            : content,
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: mobileDestinationIndexes.contains(index)
                  ? mobileDestinationIndexes.indexOf(index)
                  : mobileDestinationIndexes.length - 1,
              onDestinationSelected: (value) =>
                  setState(() => index = mobileDestinationIndexes[value]),
              destinations: mobileDestinationIndexes
                  .map((destinationIndex) => destinations[destinationIndex])
                  .toList(),
            ),
    );
  }

  Future<void> signOut() async {
    await SessionStore().clear();
    widget.onSignedOut();
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/brand/circlenet-logo.png', width: 48, height: 48),
        const SizedBox(height: 6),
        const Text('CircleNet',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12))
      ]);
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.api,
    required this.session,
    required this.onSignOut,
    required this.onSelectPrimaryPage,
  });
  final CircleNetApi api;
  final AuthTokenBundle session;
  final VoidCallback onSignOut;
  final ValueChanged<int> onSelectPrimaryPage;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _PageHeader(
              eyebrow: 'PERSONAL ASSISTANT & SETTINGS',
              title: 'Your life tools',
              subtitle:
                  'Money, memories, safety, discovery, privacy and account controls.'),
          _primaryTile(Icons.notifications_outlined, 'Notifications',
              'Review activity and important alerts.', 4),
          _primaryTile(Icons.person_search_outlined, 'Find people & circles',
              'Discover people and communities.', 5),
          _primaryTile(Icons.person_outline, 'My profile',
              'Manage your identity and profile details.', 6),
          _moreTile(
              context,
              Icons.timeline_rounded,
              'Life timeline',
              'Review your diary entries in chronological order.',
              TimelineScreen(api: api)),
          _moreTile(
              context,
              Icons.account_balance_wallet_outlined,
              'Money & insights',
              'Spending, savings and financial wellbeing.',
              FinanceScreen(api: api)),
          _moreTile(
              context,
              Icons.monitor_heart_outlined,
              'Health records',
              'Diagnostic reports, measurements and health trends.',
              HealthRecordsScreen(api: api)),
          _moreTile(
              context,
              Icons.stars_rounded,
              'Trust center',
              'Star Members, emergency access and Role Models.',
              TrustCenterScreen(api: api)),
          _moreTile(
              context,
              Icons.shield_outlined,
              'Privacy & settings',
              'Blocked accounts and privacy controls.',
              PrivacyCenterScreen(api: api)),
          _moreTile(context, Icons.flag_outlined, 'My reports',
              'Track reports you submitted.', ReportsScreen(api: api)),
          _moreTile(context, Icons.admin_panel_settings_outlined, 'Moderation',
              'Admin trust and safety queue.', ModerationScreen(api: api)),
          _moreTile(
              context,
              Icons.devices_rounded,
              'Account session',
              'Review this login and sign out securely.',
              SessionScreen(session: session, onSignOut: onSignOut)),
        ],
      );

  Widget _primaryTile(
          IconData icon, String title, String subtitle, int pageIndex) =>
      Card(
          child: ListTile(
              leading: CircleAvatar(child: Icon(icon)),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onSelectPrimaryPage(pageIndex)));

  Widget _moreTile(BuildContext context, IconData icon, String title,
          String subtitle, Widget destination) =>
      Card(
          child: ListTile(
              leading: CircleAvatar(child: Icon(icon)),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => Scaffold(
                          appBar: AppBar(title: Text(title)),
                          body: destination)))));
}

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
          future: api.socialFeed(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return _ErrorState('${snapshot.error}');
            final entries = (snapshot.data ?? [])
                .where((item) => item['mine'] == true)
                .toList();
            if (entries.isEmpty) {
              return const Center(
                  child: Text(
                      'Your timeline will grow as you add diary entries.'));
            }
            return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final item = entries[index];
                  return Card(
                      child: ListTile(
                          leading: const Icon(Icons.auto_stories_rounded),
                          title: Text(
                              (item['caption'] ??
                                      item['mediaName'] ??
                                      'Diary entry')
                                  .toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              '${item['createdAt'] ?? ''} · ${(item['audience'] ?? 'PRIVATE').toString().toLowerCase()}')));
                });
          });
}

class HealthRecordsScreen extends StatefulWidget {
  const HealthRecordsScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  Map<String, dynamic>? data;
  List<Map<String, dynamic>> docs = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait(
          [widget.api.healthDashboard(), widget.api.socialFeed()]);
      final feed = (values[1] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      if (mounted) {
        setState(() {
          data = Map<String, dynamic>.from(values[0] as Map);
          docs = feed
              .where((x) =>
                  x['mine'] == true &&
                  x['audience'] == 'PRIVATE' &&
                  x['mediaUrl'] != null)
              .map((x) =>
                  {'id': x['id'], 'name': x['mediaName'] ?? x['caption']})
              .toList();
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> add() async {
    final name = TextEditingController(),
        lab = TextEditingController(),
        metric = TextEditingController(),
        value = TextEditingController(),
        unit = TextEditingController(),
        minimum = TextEditingController(),
        maximum = TextEditingController();
    int? postId;
    final save = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                    title: const Text('Add diagnostic report'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          decoration:
                              const InputDecoration(labelText: 'Report name')),
                      TextField(
                          controller: lab,
                          decoration:
                              const InputDecoration(labelText: 'Laboratory')),
                      DropdownButtonFormField<int?>(
                          initialValue: postId,
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('No linked diary document')),
                            ...docs.map((x) => DropdownMenuItem<int?>(
                                value: x['id'] as int,
                                child: Text('${x['name']}')))
                          ],
                          onChanged: (v) => setDialog(() => postId = v),
                          decoration: const InputDecoration(
                              labelText: 'Private diary document')),
                      const Divider(height: 28),
                      TextField(
                          controller: metric,
                          decoration: const InputDecoration(
                              labelText:
                                  'Measurement (for example Hemoglobin)')),
                      TextField(
                          controller: value,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Value')),
                      TextField(
                          controller: unit,
                          decoration: const InputDecoration(labelText: 'Unit')),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: minimum,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Lab minimum'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextField(
                                controller: maximum,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Lab maximum')))
                      ]),
                      const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                              'Enter values and reference ranges exactly as printed by the laboratory. CircleNet does not diagnose conditions.'))
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save'))
                    ])));
    if (save != true || name.text.trim().isEmpty) return;
    final measurement = metric.text.trim().isEmpty
        ? const <Map<String, dynamic>>[]
        : [
            {
              'metricName': metric.text.trim(),
              'value': double.tryParse(value.text),
              'unit': unit.text.trim(),
              'referenceMin': double.tryParse(minimum.text),
              'referenceMax': double.tryParse(maximum.text)
            }
          ];
    await widget.api.addHealthReport({
      'sourcePostId': postId,
      'reportName': name.text.trim(),
      'laboratory': lab.text.trim(),
      'collectedOn': DateTime.now().toIso8601String().substring(0, 10),
      'measurements': measurement
    });
    await load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return _ErrorState(error!);
    final trends = (data?['trends'] as List? ?? []).cast<Map>();
    final reports = (data?['reports'] as List? ?? []).cast<Map>();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _PageHeader(
            eyebrow: 'PERSONAL ASSISTANT · HEALTH',
            title: 'Health records & trends',
            subtitle:
                'One private home for diagnostic reports and their measurements.',
          ),
          Card(
            color: const Color(0xfffff7df),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('ⓘ ${data?['disclaimer']}'),
            ),
          ),
          FilledButton.icon(
            onPressed: add,
            icon: const Icon(Icons.add),
            label: const Text('Add diagnostic report'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 18, bottom: 6),
            child: Text('Measurement trends',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          ...trends.map((trend) {
            final points = (trend['points'] as List).cast<Map>();
            final values = points
                .map((point) => (point['value'] as num).toDouble())
                .toList();
            final maxValue = values.fold<double>(1, math.max);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${trend['metricName']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        Text(
                            '${values.isEmpty ? '—' : values.last} ${trend['unit']}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...points.map((point) => Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Row(
                            children: [
                              SizedBox(
                                  width: 90, child: Text('${point['date']}')),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: (point['value'] as num).toDouble() /
                                      maxValue,
                                  minHeight: 10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${point['value']}'),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            );
          }),
          const Padding(
            padding: EdgeInsets.only(top: 18, bottom: 6),
            child: Text('Diagnostic reports',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          ...reports.map((report) => Card(
                child: ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.description_outlined)),
                  title: Text('${report['reportName']}'),
                  subtitle: Text(
                    '${report['laboratory'] ?? 'Laboratory not specified'} · '
                    '${report['collectedOn']}\n'
                    '${(report['measurements'] as List).length} measurements',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await widget.api.deleteHealthReport(report['id'] as int);
                      await load();
                    },
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;
  String get month => DateTime.now().toIso8601String().substring(0, 7);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final value = await widget.api.financialSummary(month);
      if (mounted) {
        setState(() {
          data = value;
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  String money(dynamic value) => '₹${(value as num? ?? 0).toStringAsFixed(0)}';
  Future<void> addManual() async {
    final amount = TextEditingController(), merchant = TextEditingController();
    String category = 'GROCERIES', direction = 'EXPENSE';
    final save = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                    title: const Text('Add transaction'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: amount,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Amount')),
                      DropdownButtonFormField<String>(
                          initialValue: direction,
                          items: const [
                            DropdownMenuItem(
                                value: 'EXPENSE', child: Text('Expense')),
                            DropdownMenuItem(
                                value: 'INCOME', child: Text('Income'))
                          ],
                          onChanged: (v) => setDialog(() => direction = v!),
                          decoration: const InputDecoration(labelText: 'Type')),
                      DropdownButtonFormField<String>(
                          initialValue: category,
                          items: [
                            'SHOPPING',
                            'GROCERIES',
                            'HEALTH',
                            'INVESTMENT',
                            'HOUSING',
                            'TRANSPORT',
                            'FOOD',
                            'UTILITIES',
                            'EDUCATION',
                            'ENTERTAINMENT',
                            'OTHER'
                          ]
                              .map((x) =>
                                  DropdownMenuItem(value: x, child: Text(x)))
                              .toList(),
                          onChanged: (v) => setDialog(() => category = v!),
                          decoration:
                              const InputDecoration(labelText: 'Category')),
                      TextField(
                          controller: merchant,
                          decoration: const InputDecoration(
                              labelText: 'Merchant or note'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save'))
                    ])));
    if (save == true) {
      await widget.api.addFinancialTransaction({
        'source': 'MANUAL',
        'amount': double.tryParse(amount.text),
        'direction': direction,
        'category': category,
        'merchant': merchant.text,
        'occurredAt': DateTime.now().toUtc().toIso8601String()
      });
      await load();
    }
  }

  Future<void> importSms() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'SMS inbox import is available on Android. Paste transactions manually on this platform.')));
      return;
    }
    final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                icon: const Icon(Icons.sms_outlined),
                title: const Text('Import financial SMS?'),
                content: const Text(
                    'CircleNet will read up to 200 recent messages on this device, select only messages that look financial, and upload those transaction messages to your private account for categorization. It will not import personal conversations. You can revoke SMS permission or delete transactions at any time.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Not now')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                            child: const Text('Agree and continue'))
                ]));
    if (approved != true) return;
    final permission = await Permission.sms.request();
    if (!permission.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS permission was not granted.')));
      }
      return;
    }
    setState(() => loading = true);
    try {
      final messages = await const MethodChannel('circlenet/sms')
              .invokeListMethod<dynamic>('financialMessages') ??
          [];
      int imported = 0;
      for (final raw in messages) {
        final item = Map<String, dynamic>.from(raw as Map);
        try {
          await widget.api.addFinancialTransaction({
            'source': 'SMS',
            'smsSender': item['sender'],
            'smsBody': item['body'],
            'occurredAt': DateTime.fromMillisecondsSinceEpoch(
                    (item['date'] as num).toInt())
                .toUtc()
                .toIso8601String()
          });
          imported++;
        } catch (_) {}
      }
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Reviewed ${messages.length} financial messages; synchronized $imported transactions.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return _ErrorState(error!);
    final categories =
            Map<String, dynamic>.from(data?['categories'] as Map? ?? {}),
        transactions = (data?['transactions'] as List? ?? []).cast<Map>();
    final maxValue = categories.values
        .fold<double>(1, (m, x) => math.max(m, (x as num).toDouble()));
    return RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const _PageHeader(
              eyebrow: 'PERSONAL ASSISTANT · MONEY',
              title: 'Financial wellbeing',
              subtitle:
                  'See spending patterns and make thoughtful next steps.'),
          Row(children: [
            Expanded(
                child: _moneyCard('Income', data?['income'], Colors.green)),
            const SizedBox(width: 8),
            Expanded(
                child: _moneyCard('Spending', data?['spending'], Colors.red)),
            const SizedBox(width: 8),
            Expanded(
                child: _moneyCard('Net saved', data?['net'], AppTheme.primary))
          ]),
          const SizedBox(height: 12),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Spending by category',
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w900)),
                        ...categories.entries.map((x) => Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(x.key),
                                        Text(money(x.value))
                                      ]),
                                  LinearProgressIndicator(
                                      value: (x.value as num).toDouble() /
                                          maxValue,
                                      minHeight: 9,
                                      borderRadius: BorderRadius.circular(9))
                                ])))
                      ]))),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ideas for your next step',
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w900)),
                        ...(data?['suggestions'] as List? ?? []).map((x) =>
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('◆ $x'))),
                        const SizedBox(height: 10),
                        Text('${data?['disclaimer']}',
                            style: Theme.of(context).textTheme.bodySmall)
                      ]))),
          Row(children: [
            Expanded(
                child: FilledButton.icon(
                    onPressed: addManual,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'))),
            const SizedBox(width: 8),
            Expanded(
                child: FilledButton.tonalIcon(
                    onPressed: importSms,
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('Import SMS')))
          ]),
          const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 6),
              child: Text('Transactions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          ...transactions.map((x) => Card(
              child: ListTile(
                  leading: CircleAvatar(
                      child: Text('${x['category']}'.substring(0, 2))),
                  title: Text('${x['merchant'] ?? x['category']}'),
                  subtitle: Text('${x['category']} · ${x['source']}'),
                  trailing: Text(
                      '${x['direction'] == 'INCOME' ? '+' : '−'}${money(x['amount'])}',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: x['direction'] == 'INCOME'
                              ? Colors.green
                              : Colors.red)))))
        ]));
  }

  Widget _moneyCard(String title, dynamic value, Color color) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 6),
            FittedBox(
                child: Text(money(value),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: color,
                        fontSize: 18)))
          ])));
}

class PrivacyCenterScreen extends StatelessWidget {
  const PrivacyCenterScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Card(
            child: ListTile(
                leading: Icon(Icons.lock_rounded),
                title: Text('Private by default'),
                subtitle: Text(
                    'New diary entries are visible only to you unless you choose another audience.'))),
        Card(
            child: ListTile(
                leading: const Icon(Icons.block_rounded),
                title: const Text('Blocked accounts'),
                subtitle: const Text('Review or unblock accounts.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => BlockedAccountsScreen(api: api)))))
      ]);
}

class TrustCenterScreen extends StatefulWidget {
  const TrustCenterScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<TrustCenterScreen> createState() => _TrustCenterScreenState();
}

class _TrustCenterScreenState extends State<TrustCenterScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> stars = [],
      models = [],
      discover = [],
      emergencies = [],
      owners = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait([
        widget.api.trustedPeople('STAR'),
        widget.api.trustedPeople('ROLE_MODEL'),
        widget.api.roleModels(),
        widget.api.emergencyRequests(),
        widget.api.inboundTrustedPeople('STAR')
      ]);
      if (mounted) {
        setState(() {
          stars = values[0];
          models = values[1];
          discover = values[2];
          emergencies = values[3];
          owners = values[4];
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> add(String kind) async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(
                    'Add ${kind == 'STAR' ? 'Star Member' : 'Role Model'}'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                        labelText: 'Name, phone or location')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Search'))
                ]));
    if (query == null || query.isEmpty) return;
    try {
      final people = await widget.api.search(query);
      if (people.isEmpty) throw Exception('No matching member found.');
      await widget.api.addTrustedPerson(people.first.id, kind);
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> requestEmergency() async {
    if (owners.isEmpty) return;
    int ownerId = owners.first['userId'] as int;
    final reason = TextEditingController();
    final sent = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                    title: const Text('Report an emergency'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<int>(
                          initialValue: ownerId,
                          items: owners
                              .map((x) => DropdownMenuItem(
                                  value: x['userId'] as int,
                                  child: Text('${x['displayName']}')))
                              .toList(),
                          onChanged: (v) =>
                              setDialog(() => ownerId = v ?? ownerId),
                          decoration: const InputDecoration(
                              labelText: 'Person needing help')),
                      TextField(
                          controller: reason,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                              labelText:
                                  'What happened and why are documents needed?'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Request access'))
                    ])));
    if (sent == true && reason.text.trim().length >= 20) {
      await widget.api.startEmergencyAccess(ownerId, reason.text.trim());
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return _ErrorState(error!);
    return RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const _PageHeader(
              eyebrow: 'SAFETY & INSPIRATION',
              title: 'Trust center',
              subtitle:
                  'Protect important life records and follow the people who inspire you.'),
          _section('Star Members',
              'Two independent Stars must verify an emergency.', stars, 'STAR'),
          _section(
              'My Role Models',
              'Members you endorse while their contact details remain private.',
              models,
              'ROLE_MODEL'),
          if (owners.isNotEmpty)
            Card(
                child: ListTile(
                    leading:
                        const Icon(Icons.emergency_rounded, color: Colors.red),
                    title: const Text('Report an emergency'),
                    subtitle: const Text(
                        'Requests expire after 24 hours; approved access lasts one hour.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: requestEmergency)),
          const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 6),
              child: Text('Discover Role Models',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          ...discover.map((x) => Card(
              child: ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.workspace_premium)),
                  title: Text('${x['displayName']}'),
                  subtitle: Text(
                      '${x['followerCount'] ?? 0} followers · contact details private'),
                  trailing: FilledButton(
                      onPressed: () async {
                        await widget.api.followRoleModel(x['userId'] as int);
                        await load();
                      },
                      child: const Text('Follow'))))),
          const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 6),
              child: Text('Emergency requests',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          ...emergencies.map((x) => Card(
              child: ListTile(
                  title: Text('${x['requesterName']} → ${x['ownerName']}'),
                  subtitle: Text(
                      '${x['reason']}\n${x['approvals']}/${x['requiredApprovals']} approvals · ${x['status']}'),
                  isThreeLine: true,
                  trailing: x['status'] == 'PENDING'
                      ? PopupMenuButton<bool>(
                          onSelected: (approved) async {
                            await widget.api.decideEmergencyAccess(
                                x['id'] as int, approved);
                            await load();
                          },
                          itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: true,
                                    child: Text('Verify & approve')),
                                PopupMenuItem(
                                    value: false, child: Text('Reject'))
                              ])
                      : null)))
        ]));
  }

  Widget _section(String title, String subtitle,
          List<Map<String, dynamic>> items, String kind) =>
      Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w900))),
                      IconButton(
                          onPressed: () => add(kind),
                          icon: const Icon(Icons.person_add_alt_1),
                          tooltip: 'Add $title')
                    ]),
                    Text(subtitle),
                    ...items.map((x) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                            kind == 'STAR'
                                ? Icons.star_rounded
                                : Icons.workspace_premium_rounded,
                            color: AppTheme.primary),
                        title: Text('${x['displayName']}'),
                        subtitle: kind == 'ROLE_MODEL'
                            ? Text('${x['followerCount'] ?? 0} followers')
                            : null,
                        trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () async {
                              await widget.api.removeTrustedPerson(
                                  x['userId'] as int, kind);
                              await load();
                            })))
                  ])));
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
          future: api.myReports(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return _ErrorState('${snapshot.error}');
            final reports = snapshot.data ?? [];
            if (reports.isEmpty) {
              return const Center(child: Text('No reports submitted.'));
            }
            return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return Card(
                      child: ListTile(
                          leading: const Icon(Icons.flag_outlined),
                          title:
                              Text((report['reason'] ?? 'Report').toString()),
                          subtitle: Text(
                              '${report['status'] ?? 'OPEN'} · Report #${report['id']}')));
                });
          });
}

class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
          future: api.moderationReports(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          'Moderation is available to administrators only.\n\n${snapshot.error}',
                          textAlign: TextAlign.center)));
            }
            final reports = snapshot.data ?? [];
            return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return Card(
                      child: ListTile(
                          leading: const Icon(Icons.gavel_rounded),
                          title:
                              Text((report['reason'] ?? 'Report').toString()),
                          subtitle: Text(
                              '${report['status'] ?? 'OPEN'} · #${report['id']}')));
                });
          });
}

class SessionScreen extends StatelessWidget {
  const SessionScreen(
      {super.key, required this.session, required this.onSignOut});
  final AuthTokenBundle session;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_rounded,
                          size: 42, color: AppTheme.primary),
                      const SizedBox(height: 12),
                      const Text('Current device is signed in',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 6),
                      Text(
                          'Access session lifetime: ${session.expiresIn} seconds'),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                          onPressed: onSignOut,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Sign out of this device'))
                    ])))
      ]);
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> items = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.api.notifications();
      if (mounted) setState(() => items = data);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> read(Map<String, dynamic> item) async {
    if (item['readAt'] != null) return;
    await widget.api.readNotification((item['id'] as num).toInt());
    await load();
  }

  Future<void> openNotification(Map<String, dynamic> item) async {
    if (item['readAt'] == null) {
      await widget.api.readNotification((item['id'] as num).toInt());
    }
    final uri = Uri.tryParse(item['actionUrl']?.toString() ?? '');
    if (!mounted || uri == null) {
      await load();
      return;
    }
    if (uri.path == '/feed') {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => SocialFeedScreen(api: widget.api)));
    } else if (uri.queryParameters['messageUserId'] != null) {
      final id = int.tryParse(uri.queryParameters['messageUserId']!);
      final relations = await widget.api.relationships();
      final matches = relations.where((r) => r.person.id == id);
      Person? person = matches.isNotEmpty ? matches.first.person : null;
      if (person == null) {
        final conversations = await widget.api.directConversations();
        final found =
            conversations.where((conversation) => conversation.userId == id);
        if (found.isNotEmpty) person = found.first.person;
      }
      if (person != null && mounted) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    DirectChatScreen(api: widget.api, person: person!)));
      }
    } else if (uri.queryParameters['callId'] != null) {
      final id = int.tryParse(uri.queryParameters['callId']!);
      if (id != null) {
        final call = await widget.api.call(id);
        if (mounted) {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      DirectCallScreen(api: widget.api, incomingCall: call)));
        }
      }
    } else if (uri.queryParameters['circleId'] != null) {
      final id = int.tryParse(uri.queryParameters['circleId']!);
      final circles = await widget.api.circles();
      final matches = circles.where((c) => c.id == id);
      if (matches.isNotEmpty && mounted) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    CircleChatScreen(api: widget.api, circle: matches.first)));
      }
    }
    await load();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        _PageHeader(
            eyebrow: 'STAY UPDATED',
            title: 'Notifications',
            subtitle: 'Messages, calls, circles and invitations.',
            action: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  tooltip: 'Preferences',
                  onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          NotificationPreferencesSheet(api: widget.api)),
                  icon: const Icon(Icons.tune_rounded)),
              IconButton(
                  tooltip: 'Mark all read',
                  onPressed: () async {
                    await widget.api.readAllNotifications();
                    await load();
                  },
                  icon: const Icon(Icons.done_all_rounded))
            ])),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error != null)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w700))),
        Expanded(
            child:
                RefreshIndicator(onRefresh: load, child: _notificationList())),
      ]);
  Widget _notificationList() {
    if (items.isEmpty && !loading) {
      return ListView(children: const [
        SizedBox(height: 120),
        Icon(Icons.notifications_none_rounded,
            size: 52, color: Color(0xFF9A8CD6)),
        Center(
            child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('You are all caught up.')))
      ]);
    }
    return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final item = items[index];
          final unread = item['readAt'] == null;
          return Material(
              color: unread ? const Color(0xFFF1ECFF) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => openNotification(item),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                                radius: 19,
                                backgroundColor: unread
                                    ? AppTheme.primary
                                    : const Color(0xFFEDEAF7),
                                child: Icon(
                                    _notificationIcon('${item['type']}'),
                                    size: 19,
                                    color: unread
                                        ? Colors.white
                                        : AppTheme.primary)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('${item['title']}',
                                      style: TextStyle(
                                          fontWeight: unread
                                              ? FontWeight.w900
                                              : FontWeight.w700,
                                          color: AppTheme.ink)),
                                  const SizedBox(height: 2),
                                  Text('${item['body']}',
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF596579))),
                                  const SizedBox(height: 4),
                                  Text(_notificationTime(item['createdAt']),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF8992A3)))
                                ])),
                            if (unread)
                              const Padding(
                                  padding: EdgeInsets.only(top: 7, left: 6),
                                  child: CircleAvatar(
                                      radius: 4,
                                      backgroundColor: AppTheme.primary))
                          ]))));
        });
  }

  IconData _notificationIcon(String type) => switch (type) {
        'DIRECT_MESSAGE' => Icons.chat_bubble_rounded,
        'CIRCLE_MESSAGE' => Icons.groups_rounded,
        'CALL' => Icons.call_rounded,
        'INVITATION' => Icons.person_add_rounded,
        'RELATIONSHIP' => Icons.family_restroom_rounded,
        _ => Icons.notifications_rounded
      };
  String _notificationTime(dynamic value) {
    final text = '${value ?? ''}';
    return text.length > 16
        ? text.substring(0, 16).replaceFirst('T', ' ')
        : text;
  }
}

class NotificationPreferencesSheet extends StatefulWidget {
  const NotificationPreferencesSheet({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<NotificationPreferencesSheet> createState() =>
      _NotificationPreferencesSheetState();
}

class _NotificationPreferencesSheetState
    extends State<NotificationPreferencesSheet> {
  Map<String, dynamic>? values;
  String? error;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    widget.api.notificationPreferences().then((v) {
      if (mounted) setState(() => values = v);
    }).catchError((e) {
      if (mounted) setState(() => error = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: values == null
              ? SizedBox(
                  height: 180,
                  child: Center(
                      child: error == null
                          ? const CircularProgressIndicator()
                          : Text(error!,
                              style: const TextStyle(color: Colors.red))))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(children: [
                        Expanded(
                            child: Text('Notification preferences',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900))),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close))
                      ]),
                      const Text('Delivery channels',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      Wrap(
                          spacing: 8,
                          children: [
                            'emailEnabled',
                            'smsEnabled',
                            'pushEnabled'
                          ]
                              .map((key) => FilterChip(
                                  label: Text(_label(key)),
                                  selected: values![key] == true,
                                  onSelected: (v) =>
                                      setState(() => values![key] = v)))
                              .toList()),
                      const SizedBox(height: 12),
                      const Text('Notify me about',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            'messagesEnabled',
                            'circlesEnabled',
                            'relationshipsEnabled',
                            'callsEnabled',
                            'invitationsEnabled',
                            'socialEnabled'
                          ]
                              .map((key) => FilterChip(
                                  label: Text(_label(key)),
                                  selected: values![key] == true,
                                  onSelected: (v) =>
                                      setState(() => values![key] = v)))
                              .toList()),
                      const SizedBox(height: 14),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              onPressed: saving ? null : save,
                              child: Text(
                                  saving ? 'Saving...' : 'Save preferences')))
                    ])));
  String _label(String key) =>
      const {
        'emailEnabled': 'Email',
        'smsEnabled': 'SMS',
        'pushEnabled': 'Push',
        'messagesEnabled': 'Messages',
        'circlesEnabled': 'Circles',
        'relationshipsEnabled': 'Relationships',
        'callsEnabled': 'Calls',
        'invitationsEnabled': 'Invitations',
        'socialEnabled': 'Likes and comments'
      }[key] ??
      key;
  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.api.updateNotificationPreferences(values!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader(
      {required this.eyebrow,
      required this.title,
      required this.subtitle,
      this.action});
  final String eyebrow, title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eyebrow,
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.ink)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(color: Color(0xFF718096), fontSize: 13))
        ])),
        if (action != null) action!
      ]));
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.person, {this.radius = 24});
  final Person person;
  final double radius;
  @override
  Widget build(BuildContext context) => CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE9E4FF),
      backgroundImage: person.profilePhoto?.isNotEmpty == true
          ? NetworkImage(person.profilePhoto!)
          : null,
      child: person.profilePhoto?.isNotEmpty == true
          ? null
          : Text(person.displayName.characters.first.toUpperCase(),
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: radius * .75,
                  color: AppTheme.primary)));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState(this.message, {this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 46, color: Color(0xFFC34D62)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFB4233C), fontWeight: FontWeight.w700)),
            if (retry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                  onPressed: retry, child: const Text('Try again'))
            ]
          ])));
}

class NetworkHome extends StatefulWidget {
  const NetworkHome({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<NetworkHome> createState() => _NetworkHomeState();
}

class _NetworkHomeState extends State<NetworkHome> {
  List<Relationship>? items;
  UserProfileModel? profile;
  bool treeView = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.api.relationships(),
        widget.api.profile(),
      ]);
      if (mounted) {
        setState(() {
          items = values[0] as List<Relationship>;
          profile = values[1] as UserProfileModel;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: _PageHeader(
                eyebrow: 'MY CIRCLENET',
                title: 'Relationships',
                subtitle: 'Your connected family and social network.',
                action: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton.filledTonal(
                      tooltip: 'Message a relationship audience',
                      onPressed: items == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => RelationshipBroadcastScreen(
                                      api: widget.api, relationships: items!))),
                      icon: const Icon(Icons.campaign_rounded)),
                  const SizedBox(width: 6),
                  SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: true,
                            icon: Icon(Icons.account_tree_rounded),
                            tooltip: 'Tree view'),
                        ButtonSegment(
                            value: false,
                            icon: Icon(Icons.view_list_rounded),
                            tooltip: 'List view')
                      ],
                      selected: {
                        treeView
                      },
                      showSelectedIcon: false,
                      onSelectionChanged: (value) =>
                          setState(() => treeView = value.first)),
                ]))),
        if (error != null)
          SliverFillRemaining(child: _ErrorState(error!, retry: load))
        else if (items == null)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else if (items!.isEmpty)
          const SliverFillRemaining(
              child: Center(
                  child: Text('Add your first relationship from Discover.')))
        else if (treeView)
          SliverFillRemaining(
              hasScrollBody: true,
              child: _FamilyTreeView(
                  relationships: items!,
                  profile: profile,
                  api: widget.api,
                  onChanged: load))
        else
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
              sliver: SliverList.separated(
                  itemCount: items!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => RelationshipTile(
                      relationship: items![i],
                      api: widget.api,
                      onRemoved: load)))
      ]));
}

class RelationshipBroadcastScreen extends StatefulWidget {
  const RelationshipBroadcastScreen(
      {super.key, required this.api, required this.relationships});
  final CircleNetApi api;
  final List<Relationship> relationships;
  @override
  State<RelationshipBroadcastScreen> createState() =>
      _RelationshipBroadcastScreenState();
}

class _RelationshipBroadcastScreenState
    extends State<RelationshipBroadcastScreen> {
  String audienceType = 'HORIZONTAL';
  int? anchorUserId;
  final locationController = TextEditingController();
  final messageController = TextEditingController();
  Map<String, dynamic>? preview;
  PlatformFile? attachment;
  bool loading = false;
  double progress = 0;
  String? error;

  @override
  void dispose() {
    locationController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Relationship broadcast')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(14), children: [
        const Text(
            'Send one private copy to everyone in the selected audience. Recipients cannot see one another.',
            style: TextStyle(color: Color(0xFF667085))),
        const SizedBox(height: 12),
        SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'HORIZONTAL',
                  label: Text('Children'),
                  icon: Icon(Icons.account_tree_rounded)),
              ButtonSegment(
                  value: 'VERTICAL',
                  label: Text('Chain'),
                  icon: Icon(Icons.vertical_align_bottom_rounded)),
              ButtonSegment(
                  value: 'LOCATION',
                  label: Text('Area'),
                  icon: Icon(Icons.location_on_outlined)),
            ],
            selected: {
              audienceType
            },
            onSelectionChanged: (values) => setState(() {
                  audienceType = values.first;
                  preview = null;
                  error = null;
                })),
        const SizedBox(height: 12),
        if (audienceType != 'LOCATION')
          DropdownButtonFormField<int>(
              initialValue: anchorUserId,
              decoration: InputDecoration(
                  labelText: audienceType == 'HORIZONTAL'
                      ? 'Parent node'
                      : 'Start person'),
              items: widget.relationships
                  .map((item) => DropdownMenuItem(
                      value: item.person.id,
                      child: Text(item.person.displayName,
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) => setState(() {
                    anchorUserId = value;
                    preview = null;
                  })),
        if (audienceType == 'LOCATION')
          TextField(
              controller: locationController,
              decoration: const InputDecoration(
                  labelText: 'City, town, area, state or country',
                  prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (_) => setState(() => preview = null)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: loading ? null : loadPreview,
            icon: const Icon(Icons.people_alt_outlined),
            label: const Text('Preview recipients')),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(error!,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w800))),
        if (preview != null) ...[
          const SizedBox(height: 10),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${(preview!['recipients'] as List).length} recipients',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        if ((preview!['excludedCount'] as num).toInt() > 0)
                          Text(
                              '${preview!['excludedCount']} managed, invited or inactive profiles excluded',
                              style: const TextStyle(
                                  color: Color(0xFF9A6A25), fontSize: 12)),
                        const Divider(),
                        Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children:
                                (preview!['recipients'] as List).map((raw) {
                              final item = raw as Map;
                              return Chip(
                                  avatar: const Icon(Icons.person_outline,
                                      size: 16),
                                  label: Text(item['displayName'].toString()));
                            }).toList()),
                      ]))),
          const SizedBox(height: 10),
          TextField(
              controller: messageController,
              minLines: 3,
              maxLines: 6,
              maxLength: 4000,
              decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Write one message for this audience…',
                  alignLabelWithHint: true)),
          Row(children: [
            OutlinedButton.icon(
                onPressed: chooseAttachment,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(attachment == null ? 'Attach' : attachment!.name,
                    overflow: TextOverflow.ellipsis)),
            if (attachment != null)
              IconButton(
                  tooltip: 'Remove attachment',
                  onPressed: () => setState(() => attachment = null),
                  icon: const Icon(Icons.close_rounded)),
            const Spacer(),
            FilledButton.icon(
                onPressed: loading ? null : send,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send')),
          ]),
          if (loading)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null)),
        ],
        if (loading && preview == null)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
      ])));

  Future<void> loadPreview() async {
    if (audienceType != 'LOCATION' && anchorUserId == null) {
      setState(() => error = 'Choose a person first.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.api.previewBroadcast(audienceType,
          anchorUserId: anchorUserId, location: locationController.text);
      if (mounted) setState(() => preview = value);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> chooseAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && mounted) {
      setState(() => attachment = result.files.single);
    }
  }

  Future<void> send() async {
    if (messageController.text.trim().isEmpty && attachment == null) {
      setState(() => error = 'Write a message or choose an attachment.');
      return;
    }
    setState(() {
      loading = true;
      progress = 0;
      error = null;
    });
    try {
      final result = await widget.api.sendBroadcast(
          audienceType, messageController.text.trim(),
          anchorUserId: anchorUserId,
          location: locationController.text,
          bytes: attachment?.bytes,
          fileName: attachment?.name, onProgress: (value) {
        if (mounted) setState(() => progress = value);
      });
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
                  title: const Text('Broadcast complete'),
                  content: Text(
                      '${result['deliveredCount']} delivered${(result['failedCount'] as num).toInt() == 0 ? '' : ', ${result['failedCount']} failed'}.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'))
                  ]));
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _FamilyTreeView extends StatefulWidget {
  const _FamilyTreeView({
    required this.relationships,
    required this.profile,
    required this.api,
    required this.onChanged,
  });

  final List<Relationship> relationships;
  final UserProfileModel? profile;
  final CircleNetApi api;
  final VoidCallback onChanged;

  static const nodeWidth = 132.0;
  static const nodeHeight = 98.0;
  static const horizontalGap = 30.0;
  static const verticalGap = 58.0;

  @override
  State<_FamilyTreeView> createState() => _FamilyTreeViewState();

  static int _levelDelta(String value) {
    final type = value.toLowerCase();
    if (type.contains('grandparent')) return 2;
    if (type.contains('parent') || type == 'father' || type == 'mother') {
      return 1;
    }
    if (type.contains('grandchild')) return -2;
    if (type == 'child' || type == 'son' || type == 'daughter') return -1;
    return 0;
  }

  static bool _isPartner(String value) =>
      value.contains('spouse') ||
      value.contains('wife') ||
      value.contains('husband');
}

class _FamilyTreeViewState extends State<_FamilyTreeView> {
  final transformation = TransformationController();
  Size? lastViewport;
  Size? lastTreeSize;

  @override
  void dispose() {
    transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout(MediaQuery.sizeOf(context).width);
    return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 92),
        decoration: BoxDecoration(
            color: const Color(0xFFFBFAFF),
            border: Border.all(color: const Color(0xFFE1DBF2)),
            borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          final treeSize = Size(layout.width, layout.height);
          if (lastViewport != viewport || lastTreeSize != treeSize) {
            lastViewport = viewport;
            lastTreeSize = treeSize;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _fit(layout, viewport));
          }
          return Stack(children: [
            InteractiveViewer(
                transformationController: transformation,
                constrained: false,
                minScale: .22,
                maxScale: 2.8,
                boundaryMargin: const EdgeInsets.all(180),
                child: SizedBox(
                    width: layout.width,
                    height: layout.height,
                    child: Stack(children: [
                      CustomPaint(
                          size: Size(layout.width, layout.height),
                          painter: _TreeConnectorPainter(
                              relationships: widget.relationships,
                              positions: layout.positions)),
                      ...widget.relationships.map((relationship) {
                        final position =
                            layout.positions[relationship.person.id]!;
                        return Positioned(
                            left: position.dx,
                            top: position.dy,
                            child: _TreePersonNode(
                                relationship: relationship,
                                onTap: () => RelationshipTile(
                                        relationship: relationship,
                                        api: widget.api,
                                        onRemoved: widget.onChanged)
                                    .showConnect(context)));
                      }),
                      Positioned(
                          left: layout.positions[-1]!.dx,
                          top: layout.positions[-1]!.dy,
                          child: _SelfTreeNode(profile: widget.profile))
                    ]))),
            Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(color: Color(0x16000000), blurRadius: 10)
                        ]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _treeControl(
                          Icons.remove_rounded, 'Zoom out', () => _zoom(.82)),
                      _treeControl(Icons.center_focus_strong_rounded,
                          'Fit tree', () => _fit(layout, viewport)),
                      _treeControl(
                          Icons.add_rounded, 'Zoom in', () => _zoom(1.2)),
                    ]))),
            Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(color: Color(0x16000000), blurRadius: 10)
                        ]),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.touch_app_rounded,
                          size: 15, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text('Tap a person',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800))
                    ])))
          ]);
        }));
  }

  Widget _treeControl(IconData icon, String tooltip, VoidCallback action) =>
      IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          padding: EdgeInsets.zero,
          tooltip: tooltip,
          onPressed: action,
          icon: Icon(icon, size: 17, color: AppTheme.primary));

  void _zoom(double factor) {
    final current = transformation.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(.22, 2.8);
    final ratio = target / current;
    transformation.value = transformation.value.clone()
      ..scaleByDouble(ratio, ratio, ratio, 1);
  }

  void _fit(_TreeLayout layout, Size viewport) {
    if (!mounted || viewport.width <= 0 || viewport.height <= 0) return;
    final scale = math
        .min((viewport.width - 24) / layout.width,
            (viewport.height - 24) / layout.height)
        .clamp(.22, 1.0);
    final dx = (viewport.width - layout.width * scale) / 2;
    final dy = math.max(12.0, (viewport.height - layout.height * scale) / 2);
    transformation.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  _TreeLayout _layout(double viewportWidth) {
    final personIds =
        widget.relationships.map((item) => item.person.id).toSet();
    final levels = <int, int>{-1: 0};
    for (var pass = 0; pass < widget.relationships.length + 2; pass++) {
      var changed = false;
      for (final item in widget.relationships) {
        if (levels.containsKey(item.person.id)) continue;
        final anchor = item.relativeToUserId;
        final anchorId =
            anchor != null && personIds.contains(anchor) ? anchor : -1;
        final anchorLevel = levels[anchorId];
        if (anchorLevel == null) continue;
        levels[item.person.id] =
            anchorLevel + _FamilyTreeView._levelDelta(item.type);
        changed = true;
      }
      if (!changed) break;
    }
    for (final item in widget.relationships) {
      levels.putIfAbsent(item.person.id, () => 0);
    }

    final byLevel = <int, List<int>>{};
    levels.forEach((id, level) => byLevel.putIfAbsent(level, () => []).add(id));
    final minLevel = levels.values.reduce(math.min);
    final maxLevel = levels.values.reduce(math.max);
    final maxNodes =
        byLevel.values.map((items) => items.length).reduce(math.max);
    final width = math.max(
        viewportWidth - 24,
        maxNodes * _FamilyTreeView.nodeWidth +
            math.max(0, maxNodes - 1) * _FamilyTreeView.horizontalGap +
            80);
    final height = (maxLevel - minLevel + 1) *
            (_FamilyTreeView.nodeHeight + _FamilyTreeView.verticalGap) +
        80;
    final positions = <int, Offset>{};
    for (var level = maxLevel; level >= minLevel; level--) {
      final ids = byLevel[level] ?? [];
      final ordered = _orderedRow(ids);
      final rowWidth = ordered.length * _FamilyTreeView.nodeWidth +
          math.max(0, ordered.length - 1) * _FamilyTreeView.horizontalGap;
      final start = (width - rowWidth) / 2;
      for (var index = 0; index < ordered.length; index++) {
        positions[ordered[index]] = Offset(
            start +
                index *
                    (_FamilyTreeView.nodeWidth + _FamilyTreeView.horizontalGap),
            38 +
                (maxLevel - level) *
                    (_FamilyTreeView.nodeHeight + _FamilyTreeView.verticalGap));
      }
    }
    return _TreeLayout(width, height, positions);
  }

  int _order(int id) {
    if (id == -1) return 50;
    final item =
        widget.relationships.firstWhere((value) => value.person.id == id);
    final type = item.type.toLowerCase();
    if (type.contains('brother') ||
        type.contains('sister') ||
        type.contains('sibling')) {
      return 20;
    }
    if (_FamilyTreeView._isPartner(type)) return 60;
    return 40;
  }

  List<int> _orderedRow(List<int> ids) {
    final remaining = ids.toSet();
    final result = <int>[];
    final bases = ids
        .where((id) =>
            id == -1 ||
            !_FamilyTreeView._isPartner(widget.relationships
                .firstWhere((item) => item.person.id == id)
                .type
                .toLowerCase()))
        .toList()
      ..sort((a, b) => _order(a).compareTo(_order(b)));
    for (final id in bases) {
      if (!remaining.remove(id)) continue;
      result.add(id);
      final partners = widget.relationships
          .where((item) =>
              remaining.contains(item.person.id) &&
              item.relativeToUserId == (id == -1 ? null : id) &&
              _FamilyTreeView._isPartner(item.type.toLowerCase()))
          .map((item) => item.person.id)
          .toList();
      for (final partner in partners) {
        remaining.remove(partner);
        result.add(partner);
      }
    }
    final rest = remaining.toList()
      ..sort((a, b) => _order(a).compareTo(_order(b)));
    result.addAll(rest);
    return result;
  }
}

class _TreeLayout {
  const _TreeLayout(this.width, this.height, this.positions);
  final double width, height;
  final Map<int, Offset> positions;
}

class _TreeConnectorPainter extends CustomPainter {
  const _TreeConnectorPainter(
      {required this.relationships, required this.positions});
  final List<Relationship> relationships;
  final Map<int, Offset> positions;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF75639B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = const Color(0xFF75639B);
    final ids = relationships.map((item) => item.person.id).toSet();
    for (final item in relationships) {
      final target = positions[item.person.id];
      final anchorId =
          item.relativeToUserId != null && ids.contains(item.relativeToUserId)
              ? item.relativeToUserId!
              : -1;
      final source = positions[anchorId];
      if (source == null || target == null) continue;
      final partner = _FamilyTreeView._isPartner(item.type.toLowerCase());
      final sourceCenter = Offset(source.dx + _FamilyTreeView.nodeWidth / 2,
          source.dy + _FamilyTreeView.nodeHeight / 2);
      final targetCenter = Offset(target.dx + _FamilyTreeView.nodeWidth / 2,
          target.dy + _FamilyTreeView.nodeHeight / 2);
      if (partner) {
        canvas.drawLine(
            sourceCenter,
            targetCenter,
            Paint()
              ..color = const Color(0xFFE36A98)
              ..strokeWidth = 2.4);
        _label(
            canvas,
            '♥',
            Offset((sourceCenter.dx + targetCenter.dx) / 2,
                (sourceCenter.dy + targetCenter.dy) / 2 - 9),
            color: const Color(0xFFD34F80));
        continue;
      }
      final downward = targetCenter.dy > sourceCenter.dy;
      var sourceX = sourceCenter.dx;
      if (downward) {
        final partnerPositions = relationships
            .where((candidate) {
              final candidateAnchor = candidate.relativeToUserId ?? -1;
              return candidateAnchor == anchorId &&
                  _FamilyTreeView._isPartner(candidate.type.toLowerCase());
            })
            .map((candidate) => positions[candidate.person.id])
            .whereType<Offset>()
            .toList();
        if (partnerPositions.isNotEmpty) {
          sourceX = ([source, ...partnerPositions].fold<double>(
                  0,
                  (sum, value) =>
                      sum + value.dx + _FamilyTreeView.nodeWidth / 2)) /
              (partnerPositions.length + 1);
        }
      }
      final start = Offset(sourceX,
          downward ? source.dy + _FamilyTreeView.nodeHeight : source.dy);
      final end = Offset(targetCenter.dx,
          downward ? target.dy : target.dy + _FamilyTreeView.nodeHeight);
      final midY = (start.dy + end.dy) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx, midY)
        ..lineTo(end.dx, midY)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, line);
      final direction = downward ? 1.0 : -1.0;
      canvas.drawPath(
          Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo(end.dx - 5, end.dy - 8 * direction)
            ..lineTo(end.dx + 5, end.dy - 8 * direction)
            ..close(),
          fill);
      _label(canvas, item.type, Offset(end.dx, midY - 8));
    }
  }

  void _label(Canvas canvas, String text, Offset center,
      {Color color = const Color(0xFF56437F)}) {
    final displayText =
        text.codeUnits.contains(226) ? String.fromCharCode(0x2665) : text;
    final painter = TextPainter(
        text: TextSpan(
            text: displayText,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TreeConnectorPainter oldDelegate) =>
      oldDelegate.relationships != relationships ||
      oldDelegate.positions != positions;
}

class _TreePersonNode extends StatelessWidget {
  const _TreePersonNode({required this.relationship, required this.onTap});
  final Relationship relationship;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gender = (relationship.person.gender ?? '').toUpperCase();
    final border = gender == 'FEMALE'
        ? const Color(0xFFF1A1C4)
        : gender == 'MALE'
            ? const Color(0xFF77C8F4)
            : const Color(0xFFF2BC68);
    return SizedBox(
        width: _FamilyTreeView.nodeWidth,
        height: _FamilyTreeView.nodeHeight,
        child: Material(
            color: Colors.white,
            elevation: 3,
            shadowColor: border.withValues(alpha: .25),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: border, width: 2)),
            child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Avatar(relationship.person, radius: 25),
                          const SizedBox(height: 5),
                          Text(relationship.person.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w900)),
                          Text(relationship.type,
                              maxLines: 1,
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800))
                        ])))));
  }
}

class _SelfTreeNode extends StatelessWidget {
  const _SelfTreeNode({required this.profile});
  final UserProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    final name = [profile?.value('firstName'), profile?.value('surname')]
        .where((value) => value?.trim().isNotEmpty == true)
        .join(' ');
    final photo = profile?.value('profilePhoto') ?? '';
    return SizedBox(
        width: _FamilyTreeView.nodeWidth,
        height: _FamilyTreeView.nodeHeight,
        child: DecoratedBox(
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6957CF), Color(0xFF9670D8)]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x33705CC6), blurRadius: 18)
                ]),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white24,
                  backgroundImage:
                      photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty
                      ? Text(name.isEmpty ? 'Y' : name.characters.first,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900))
                      : null),
              const SizedBox(height: 5),
              Text(name.isEmpty ? 'You' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
              const Text('You',
                  style: TextStyle(color: Colors.white70, fontSize: 9))
            ])));
  }
}

class RelationshipTile extends StatelessWidget {
  const RelationshipTile(
      {super.key,
      required this.relationship,
      required this.api,
      required this.onRemoved});
  final Relationship relationship;
  final CircleNetApi api;
  final VoidCallback onRemoved;
  @override
  Widget build(BuildContext context) {
    final person = relationship.person;
    return Card(
        child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => showConnect(context),
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  _Avatar(person),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(person.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.ink)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 5, children: [
                          _Tag(relationship.type, const Color(0xFFE2F6EC),
                              const Color(0xFF157A4B)),
                          _Tag(relationship.visibilityScope,
                              const Color(0xFFECE7FF), const Color(0xFF5A43A5)),
                          _Tag(
                              person.accountStatus == 'ACTIVE'
                                  ? 'Verified'
                                  : 'Not verified',
                              person.accountStatus == 'ACTIVE'
                                  ? const Color(0xFFE2F6EC)
                                  : const Color(0xFFFFEFC7),
                              person.accountStatus == 'ACTIVE'
                                  ? const Color(0xFF157A4B)
                                  : const Color(0xFF9A6100))
                        ])
                      ])),
                  IconButton.filledTonal(
                      tooltip: 'Person actions',
                      onPressed: () => showConnect(context),
                      icon: const Icon(Icons.more_horiz_rounded))
                ]))));
  }

  void showConnect(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(relationship.person.displayName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    const Text('Choose how you want to connect.',
                        style: TextStyle(color: Color(0xFF718096))),
                    const SizedBox(height: 16),
                    _ConnectAction(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Text message',
                        color: AppTheme.primary,
                        onTap: () {
                          if (!relationship.person.canConnect) {
                            _showCommunicationUnavailable(context);
                            return;
                          }
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DirectChatScreen(
                                      api: api, person: relationship.person)));
                        }),
                    _ConnectAction(
                        icon: Icons.call_rounded,
                        label: 'Audio call',
                        color: const Color(0xFF16875C),
                        onTap: () => relationship.person.canConnect
                            ? _startCall(context, 'AUDIO')
                            : _showCommunicationUnavailable(context)),
                    _ConnectAction(
                        icon: Icons.videocam_rounded,
                        label: 'Video call',
                        color: const Color(0xFFD15C87),
                        onTap: () => relationship.person.canConnect
                            ? _startCall(context, 'VIDEO')
                            : _showCommunicationUnavailable(context)),
                    const Divider(height: 22),
                    _ConnectAction(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Add relationship to this person',
                        color: const Color(0xFF16875C),
                        onTap: () {
                          Navigator.pop(context);
                          _addRelationship(context);
                        }),
                    _ConnectAction(
                        icon: Icons.edit_rounded,
                        label: 'Edit relationship',
                        color: AppTheme.primary,
                        onTap: () {
                          Navigator.pop(context);
                          _edit(context);
                        }),
                    _ConnectAction(
                        icon: Icons.person_remove_rounded,
                        label: 'Remove relationship',
                        color: const Color(0xFFB4233C),
                        onTap: () {
                          Navigator.pop(context);
                          _remove(context);
                        })
                  ]))));

  Future<
      void> _showCommunicationUnavailable(BuildContext context) => showDialog<
          void>(
      context: context,
      builder: (context) => AlertDialog(
              icon: const Icon(Icons.pending_actions_outlined,
                  color: AppTheme.primary),
              title: const Text('Communication not active yet'),
              content: Text(
                  '${relationship.person.displayName} can receive messages and calls after activating their CircleNet account. The communication options will remain available here.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'))
              ]));

  Future<void> _addRelationship(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    var type = 'Relative';
    var visibility = 'RELATIVES';
    final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
            builder: (context, setModal) => SafeArea(
                child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20,
                        24 + MediaQuery.viewInsetsOf(context).bottom),
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          'Add relationship to ${relationship.person.displayName}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                          'This person will appear directly in ${relationship.person.displayName}â€™s family branch.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF718096))),
                      const SizedBox(height: 16),
                      TextField(
                          controller: name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline_rounded))),
                      const SizedBox(height: 10),
                      TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                              labelText: 'Mobile number (optional)',
                              prefixIcon: Icon(Icons.phone_outlined))),
                      const SizedBox(height: 10),
                      TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                              labelText: 'Email (optional)',
                              prefixIcon: Icon(Icons.email_outlined))),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration: InputDecoration(
                              labelText:
                                  'Relationship to ${relationship.person.displayName}'),
                          items: const [
                            'Father',
                            'Mother',
                            'Husband',
                            'Wife',
                            'Son',
                            'Daughter',
                            'Brother',
                            'Sister',
                            'Grandfather',
                            'Grandmother',
                            'Grandson',
                            'Granddaughter',
                            'Uncle',
                            'Aunt',
                            'Nephew',
                            'Niece',
                            'Cousin',
                            'Guardian',
                            'Relative',
                            'Friend',
                            'Colleague',
                            'Other'
                          ]
                              .map((value) => DropdownMenuItem(
                                  value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) => setModal(() => type = value!)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          initialValue: visibility,
                          decoration:
                              const InputDecoration(labelText: 'Who can view'),
                          items: const [
                            DropdownMenuItem(
                                value: 'RELATIVES', child: Text('Relatives')),
                            DropdownMenuItem(
                                value: 'FRIENDS', child: Text('Friends')),
                            DropdownMenuItem(
                                value: 'COLLEAGUES', child: Text('Colleagues')),
                            DropdownMenuItem(
                                value: 'PUBLIC', child: Text('Public'))
                          ],
                          onChanged: (value) =>
                              setModal(() => visibility = value!)),
                      const SizedBox(height: 18),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              onPressed: () {
                                if (name.text.trim().isEmpty) return;
                                Navigator.pop(context, true);
                              },
                              label: const Text('Add relationship')))
                    ]))))));
    if (saved != true) {
      name.dispose();
      phone.dispose();
      email.dispose();
      return;
    }
    try {
      await api.addPersonRelationship(
          fullName: name.text,
          phoneNumber: phone.text.isEmpty ? null : phone.text,
          email: email.text.isEmpty ? null : email.text,
          type: type,
          visibility: visibility,
          relativeToUserId: relationship.person.id);
      onRemoved();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${name.text.trim()} added to ${relationship.person.displayName}â€™s branch.')));
      }
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(exception.toString()),
            backgroundColor: const Color(0xFFB4233C)));
      }
    } finally {
      name.dispose();
      phone.dispose();
      email.dispose();
    }
  }

  void _startCall(BuildContext context, String type) {
    Navigator.pop(context);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DirectCallScreen(
                api: api, person: relationship.person, callType: type)));
  }

  Future<void> _edit(BuildContext context) async {
    var type = relationship.type;
    var visibility = relationship.visibilityScope;
    final saved = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
            builder: (context, setModal) => SafeArea(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Edit ${relationship.person.displayName}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration:
                              const InputDecoration(labelText: 'Relationship'),
                          items: const [
                            'Friend',
                            'Spouse',
                            'Father',
                            'Mother',
                            'Parent',
                            'Child',
                            'Son',
                            'Daughter',
                            'Sibling',
                            'Brother',
                            'Sister',
                            'Colleague',
                            'Relative'
                          ]
                              .map((value) => DropdownMenuItem(
                                  value: value, child: Text(value)))
                              .toList(),
                          onChanged: (value) => setModal(() => type = value!)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          initialValue: visibility,
                          decoration: const InputDecoration(labelText: 'View'),
                          items: const [
                            DropdownMenuItem(
                                value: 'FRIENDS', child: Text('Friends')),
                            DropdownMenuItem(
                                value: 'RELATIVES', child: Text('Relatives')),
                            DropdownMenuItem(
                                value: 'COLLEAGUES', child: Text('Colleagues')),
                            DropdownMenuItem(
                                value: 'PUBLIC', child: Text('Public'))
                          ],
                          onChanged: (value) =>
                              setModal(() => visibility = value!)),
                      const SizedBox(height: 16),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Save changes')))
                    ])))));
    if (saved != true) return;
    try {
      await api.updateRelationship(relationship, type, visibility);
      onRemoved();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFB4233C)));
      }
    }
  }

  Future<void> _remove(BuildContext context) async {
    final confirmed = await _confirmDestructiveAction(context,
        title: 'Remove relationship?',
        message:
            '${relationship.person.displayName} will disappear from your relationship tree and circles will no longer use this relationship. Their CircleNet account and your existing messages are not deleted.',
        confirmLabel: 'Remove relationship');
    if (confirmed != true) return;
    try {
      await api.removeRelationship(relationship.id);
      onRemoved();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFB4233C)));
      }
    }
  }
}

class DirectCallScreen extends StatefulWidget {
  const DirectCallScreen(
      {super.key,
      required this.api,
      this.person,
      this.callType = 'AUDIO',
      this.incomingCall});
  final CircleNetApi api;
  final Person? person;
  final String callType;
  final DirectCallModel? incomingCall;

  @override
  State<DirectCallScreen> createState() => _DirectCallScreenState();
}

class _DirectCallScreenState extends State<DirectCallScreen> {
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? peer;
  MediaStream? localStream;
  DirectCallModel? call;
  Timer? poller;
  String phase = 'Preparing devices...';
  String? error;
  bool muted = false;
  bool cameraEnabled = true;

  bool get video => (call?.callType ?? widget.callType) == 'VIDEO';
  String get personName =>
      widget.incomingCall?.callerName ??
      widget.person?.displayName ??
      'CircleNet member';

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      await Future.wait(
          [localRenderer.initialize(), remoteRenderer.initialize()]);
      localStream = await navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': video});
      localRenderer.srcObject = localStream;
      peer = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'}
        ]
      });
      for (final track in localStream!.getTracks()) {
        await peer!.addTrack(track, localStream!);
      }
      peer!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams.first;
          if (mounted) setState(() => phase = 'Connected');
        }
      };
      peer!.onConnectionState = (state) {
        if (!mounted) return;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          setState(() => phase = 'Connected');
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          setState(() => error = 'Call connection was interrupted.');
        }
      };
      if (widget.incomingCall != null) {
        await answer(widget.incomingCall!);
      } else {
        await start();
      }
    } catch (e) {
      if (mounted) setState(() => error = _friendlyError(e));
    }
  }

  Future<void> start() async {
    final offer = await peer!.createOffer();
    await peer!.setLocalDescription(offer);
    await _waitForIce();
    final description = await peer!.getLocalDescription();
    call = await widget.api.startCall(
        widget.person!.id, widget.callType, jsonEncode(description!.toMap()));
    if (mounted) setState(() => phase = 'Ringing...');
    poller = Timer.periodic(const Duration(seconds: 2), (_) => pollCall());
  }

  Future<void> answer(DirectCallModel incoming) async {
    call = incoming;
    final offer = jsonDecode(incoming.offerSdp) as Map<String, dynamic>;
    await peer!.setRemoteDescription(RTCSessionDescription(
        offer['sdp'] as String?, offer['type'] as String?));
    final answer = await peer!.createAnswer();
    await peer!.setLocalDescription(answer);
    await _waitForIce();
    final description = await peer!.getLocalDescription();
    call = await widget.api
        .acceptCall(incoming.id, jsonEncode(description!.toMap()));
    if (mounted) setState(() => phase = 'Connecting...');
  }

  Future<void> pollCall() async {
    if (call == null) return;
    try {
      final current = await widget.api.call(call!.id);
      call = current;
      if (current.status == 'ACCEPTED' && current.answerSdp != null) {
        poller?.cancel();
        final answer = jsonDecode(current.answerSdp!) as Map<String, dynamic>;
        await peer!.setRemoteDescription(RTCSessionDescription(
            answer['sdp'] as String?, answer['type'] as String?));
        if (mounted) setState(() => phase = 'Connected');
      } else if (current.status == 'REJECTED' || current.status == 'ENDED') {
        poller?.cancel();
        if (mounted) {
          setState(() => error =
              current.status == 'REJECTED' ? 'Call declined.' : 'Call ended.');
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = _friendlyError(e));
    }
  }

  Future<void> _waitForIce() async {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (peer?.iceGatheringState ==
          RTCIceGatheringState.RTCIceGatheringStateComplete) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> end() async {
    if (call != null) {
      try {
        await widget.api.endCall(call!.id);
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  void toggleMute() {
    muted = !muted;
    for (final track in localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    setState(() {});
  }

  void toggleCamera() {
    cameraEnabled = !cameraEnabled;
    for (final track in localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = cameraEnabled;
    }
    setState(() {});
  }

  String _friendlyError(Object value) {
    final text = value.toString();
    if (text.toLowerCase().contains('permission')) {
      return 'Microphone or camera permission was denied. Enable it in device settings and try again.';
    }
    return text;
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => end(),
      child: Scaffold(
          backgroundColor: const Color(0xFF17132A),
          body: SafeArea(
              child: Stack(fit: StackFit.expand, children: [
            if (video && remoteRenderer.srcObject != null)
              RTCVideoView(remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!video || remoteRenderer.srcObject == null)
                CircleAvatar(
                    radius: 56,
                    backgroundColor: const Color(0xFF6F5BD3),
                    backgroundImage: (widget.incomingCall?.callerPhoto ??
                                    widget.person?.profilePhoto)
                                ?.isNotEmpty ==
                            true
                        ? NetworkImage(widget.incomingCall?.callerPhoto ??
                            widget.person!.profilePhoto!)
                        : null,
                    child: (widget.incomingCall?.callerPhoto ??
                                    widget.person?.profilePhoto)
                                ?.isNotEmpty ==
                            true
                        ? null
                        : Text(personName.characters.first,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w900))),
              const SizedBox(height: 16),
              Text(personName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(error ?? phase,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: error == null
                          ? Colors.white70
                          : const Color(0xFFFF9BAE),
                      fontWeight: FontWeight.w700))
            ])),
            if (video && localRenderer.srcObject != null)
              Positioned(
                  right: 16,
                  top: 18,
                  width: 112,
                  height: 158,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: RTCVideoView(localRenderer, mirror: true))),
            Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _CallControl(
                      icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      onTap: toggleMute),
                  if (video) ...[
                    const SizedBox(width: 18),
                    _CallControl(
                        icon: cameraEnabled
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                        onTap: toggleCamera)
                  ],
                  const SizedBox(width: 18),
                  _CallControl(
                      icon: Icons.call_end_rounded,
                      color: const Color(0xFFE54B64),
                      onTap: end)
                ]))
          ]))));

  @override
  void dispose() {
    poller?.cancel();
    for (final track in localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    peer?.close();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl(
      {required this.icon, required this.onTap, this.color = Colors.white24});
  final IconData icon;
  final Color color;
  final FutureOr<void> Function() onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
              dimension: 58,
              child: Icon(icon, color: Colors.white, size: 27))));
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.background, this.foreground);
  final String text;
  final Color background, foreground;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(
              color: foreground, fontSize: 10, fontWeight: FontWeight.w900)));
}

class _FeedImageAttachment extends StatelessWidget {
  const _FeedImageAttachment({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: 'Open $name full screen',
      child: InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) =>
                      _FullScreenImageViewer(bytes: bytes, name: name))),
          child: Stack(alignment: Alignment.bottomRight, children: [
            Container(
                width: double.infinity,
                height: 230,
                color: const Color(0xFFF3F0F8),
                child: Image.memory(bytes, fit: BoxFit.contain)),
            Container(
                margin: const EdgeInsets.all(10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(999)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.zoom_in_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text('View full size',
                      style: TextStyle(color: Colors.white, fontSize: 11))
                ]))
          ])));
}

class _FullScreenImageViewer extends StatefulWidget {
  const _FullScreenImageViewer({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final TransformationController controller = TransformationController();
  double scale = 1;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void setScale(double value) {
    scale = value.clamp(.5, 8);
    controller.value = Matrix4.diagonal3Values(scale, scale, 1);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFF100E14),
      appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title:
              Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
                tooltip: 'Reset zoom',
                onPressed: () => setScale(1),
                icon: const Icon(Icons.center_focus_strong_rounded))
          ]),
      body: Stack(children: [
        Positioned.fill(
            child: InteractiveViewer(
                transformationController: controller,
                minScale: .5,
                maxScale: 8,
                boundaryMargin: const EdgeInsets.all(120),
                onInteractionEnd: (_) => setState(
                    () => scale = controller.value.getMaxScaleOnAxis()),
                child: Center(child: Image.memory(widget.bytes)))),
        Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: SafeArea(
                child: Center(
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .78),
                            borderRadius: BorderRadius.circular(999)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              tooltip: 'Zoom out',
                              color: Colors.white,
                              onPressed: () => setScale(scale / 1.35),
                              icon: const Icon(Icons.remove_rounded)),
                          Text('${(scale * 100).round()}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                          IconButton(
                              tooltip: 'Zoom in',
                              color: Colors.white,
                              onPressed: () => setScale(scale * 1.35),
                              icon: const Icon(Icons.add_rounded))
                        ])))))
      ]));
}

class _ConnectAction extends StatelessWidget {
  const _ConnectAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(icon, color: color)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap);
}

Future<bool> _confirmDestructiveAction(BuildContext context,
        {required String title,
        required String message,
        required String confirmLabel}) async =>
    await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                icon: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFB4233C), size: 34),
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB4233C)),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(confirmLabel))
                ])) ??
    false;

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<DirectConversation>? items;
  String? error;
  Timer? poller;
  @override
  void initState() {
    super.initState();
    load();
    poller = Timer.periodic(const Duration(seconds: 5), (_) => load());
  }

  @override
  void dispose() {
    poller?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final value = await widget.api.directConversations();
      if (mounted) {
        setState(() {
          items = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: CustomScrollView(slivers: [
        const SliverToBoxAdapter(
            child: _PageHeader(
                eyebrow: 'PRIVATE MESSAGES',
                title: 'Conversations',
                subtitle: 'Recent chats and unread messages.')),
        if (error != null)
          SliverToBoxAdapter(child: _ErrorState(error!, retry: load)),
        if (items == null)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else if (items!.isEmpty)
          const SliverFillRemaining(
              child: Center(
                  child:
                      Text('No conversations yet. Start from a relationship.')))
        else
          SliverList.builder(
              itemCount: items!.length,
              itemBuilder: (context, index) {
                final item = items![index];
                return ListTile(
                    leading: CircleAvatar(
                        backgroundImage: item.profilePhoto?.isNotEmpty == true
                            ? NetworkImage(item.profilePhoto!)
                            : null,
                        child: item.profilePhoto?.isNotEmpty == true
                            ? null
                            : Text(item.displayName
                                .substring(0, 1)
                                .toUpperCase())),
                    title: Text(item.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(item.lastMessage,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: item.unreadCount > 0
                        ? Badge(
                            label: Text(item.unreadCount > 99
                                ? '99+'
                                : '${item.unreadCount}'))
                        : Text(_time(item.lastMessageAt),
                            style: const TextStyle(fontSize: 10)),
                    onTap: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => DirectChatScreen(
                                  api: widget.api, person: item.person)));
                      await load();
                    });
              })
      ]));
}

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  final caption = TextEditingController();
  final comment = TextEditingController();
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> stories = [];
  bool loading = true;
  String error = '';
  PlatformFile? selected;
  bool savedOnly = false;
  String audience = 'PRIVATE';
  int? selectedCircleId;
  List<CircleModel> availableCircles = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    caption.dispose();
    comment.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        savedOnly ? widget.api.savedSocialPosts() : widget.api.socialFeed(),
        widget.api.socialStories(),
        widget.api.circles()
      ]);
      if (mounted) {
        setState(() {
          posts = values[0] as List<Map<String, dynamic>>;
          stories = values[1] as List<Map<String, dynamic>>;
          availableCircles = values[2] as List<CircleModel>;
          loading = false;
          error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> pick() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'jfif',
          'png',
          'webp',
          'gif',
          'bmp',
          'tif',
          'tiff',
          'avif',
          'heic',
          'heif',
          'ico',
          'svg',
          'psd',
          'dng',
          'cr2',
          'nef',
          'arw',
          'glb',
          'gltf',
          'obj',
          'stl',
          'fbx',
          '3mf',
          'dae',
          'ply',
          'usdz',
          'blend',
          'mp4',
          'm4v',
          'mov',
          'avi',
          'mkv',
          'webm',
          'mpeg',
          'mpg',
          'ogv',
          '3gp',
          '3g2',
          'flv',
          'mp3',
          'm4a',
          'aac',
          'wav',
          'flac',
          'ogg',
          'oga',
          'opus',
          'amr',
          'aif',
          'aiff',
          'mid',
          'midi',
          'pdf',
          'txt',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx'
        ],
        withData: true);
    if (result != null && mounted) {
      setState(() => selected = result.files.single);
    }
  }

  Future<void> publish() async {
    if (caption.text.trim().isEmpty && selected == null) return;
    setState(() => loading = true);
    try {
      await widget.api.createSocialPost(caption.text.trim(), audience,
          circleId: audience == 'CIRCLE' ? selectedCircleId : null,
          bytes: selected?.bytes,
          fileName: selected?.name);
      caption.clear();
      selected = null;
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> story() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.media, withData: true);
    final f = result?.files.single;
    if (f?.bytes == null) return;
    setState(() => loading = true);
    try {
      await widget.api.createSocialStory('', f!.bytes!, f.name);
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> viewStory(Map<String, dynamic> story) async {
    final path = story['mediaUrl']?.toString();
    if (path == null) return;
    try {
      if (story['mine'] != true) {
        story.addAll(
            await widget.api.viewSocialStory((story['id'] as num).toInt()));
        if (mounted) setState(() {});
      }
      final bytes = await widget.api.socialMedia(path);
      if (!mounted) return;
      final type = story['mediaType']?.toString() ?? 'application/octet-stream';
      if (!type.startsWith('image/')) {
        final extension = type.startsWith('video/') ? 'mp4' : 'bin';
        final opened = await openAttachmentBytes(
            bytes, type, 'story-${story['id']}.$extension');
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No app is available to open this story.')));
        }
        return;
      }
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: SafeArea(
                  child: Stack(children: [
                Center(
                    child: InteractiveViewer(
                        child: Image.memory(bytes,
                            width: double.infinity, fit: BoxFit.contain))),
                Positioned(
                    left: 16,
                    right: 8,
                    top: 8,
                    child: Row(children: [
                      CircleAvatar(
                          child: Text((story['authorName'] ?? '?')
                              .toString()
                              .substring(0, 1)
                              .toUpperCase())),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(story['authorName']?.toString() ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900))),
                      if (story['mine'] == true)
                        IconButton(
                            tooltip: 'Delete story',
                            color: Colors.white,
                            onPressed: () async {
                              final confirmed = await _confirmDestructiveAction(
                                  dialogContext,
                                  title: 'Delete story?',
                                  message:
                                      'This story will be removed immediately and people will no longer be able to view it. This action cannot be undone.',
                                  confirmLabel: 'Delete story');
                              if (!confirmed) return;
                              await widget.api.deleteSocialStory(
                                  (story['id'] as num).toInt());
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              await load();
                            },
                            icon: const Icon(Icons.delete_outline_rounded)),
                      IconButton(
                          tooltip: 'Close',
                          color: Colors.white,
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded))
                    ])),
                if ((story['caption'] ?? '').toString().isNotEmpty)
                  Positioned(
                      left: 20,
                      right: 20,
                      bottom: 24,
                      child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(story['caption'].toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white))))
              ]))));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(savedOnly ? 'Saved moments' : 'Digital diary & feed',
                    style: Theme.of(context).textTheme.headlineMedium),
                const Text('Thoughts, memories, documents and shared moments.')
              ])),
          IconButton.filledTonal(
              tooltip: savedOnly ? 'Show all posts' : 'Saved posts',
              onPressed: loading
                  ? null
                  : () {
                      setState(() => savedOnly = !savedOnly);
                      load();
                    },
              icon: Icon(savedOnly
                  ? Icons.dynamic_feed_outlined
                  : Icons.bookmark_outline_rounded)),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
              onPressed: loading ? null : story,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Story')),
          IconButton(
              tooltip: 'My reports',
              onPressed: showMyReports,
              icon: const Icon(Icons.flag_outlined))
        ]),
        const SizedBox(height: 14),
        if (stories.isNotEmpty)
          SizedBox(
              height: 92,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: stories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final s = stories[i];
                    return SizedBox(
                        width: 72,
                        child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => viewStory(s),
                            onLongPress: s['mine'] == true
                                ? () async {
                                    final remove = await _confirmDestructiveAction(
                                        context,
                                        title: 'Delete story?',
                                        message:
                                            'This story will be removed immediately and people will no longer be able to view it. This action cannot be undone.',
                                        confirmLabel: 'Delete story');
                                    if (remove == true) {
                                      await widget.api.deleteSocialStory(
                                          (s['id'] as num).toInt());
                                      await load();
                                    }
                                  }
                                : null,
                            child: Column(children: [
                              CircleAvatar(
                                  radius: 27,
                                  backgroundColor: s['viewedByMe'] == true
                                      ? Colors.grey.shade400
                                      : AppTheme.primary,
                                  child: Text((s['authorName'] ?? '?')
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase())),
                              Text(s['authorName']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                              if (s['mine'] == true)
                                Text('${s['viewCount'] ?? 0} views',
                                    style:
                                        Theme.of(context).textTheme.labelSmall)
                            ])));
                  })),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  TextField(
                      controller: caption,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          hintText: 'What would you like to remember today?',
                          border: InputBorder.none)),
                  DropdownButtonFormField<String>(
                      initialValue: audience,
                      decoration: const InputDecoration(
                          labelText: 'Who can view this?'),
                      items: const [
                        DropdownMenuItem(
                            value: 'PRIVATE', child: Text('Private — only me')),
                        DropdownMenuItem(
                            value: 'PUBLIC', child: Text('Public — everyone')),
                        DropdownMenuItem(
                            value: 'FRIENDS', child: Text('Friends')),
                        DropdownMenuItem(
                            value: 'RELATIVES', child: Text('Relatives')),
                        DropdownMenuItem(
                            value: 'RELATIONSHIPS',
                            child: Text('All relationships')),
                        DropdownMenuItem(
                            value: 'CIRCLE', child: Text('Selected circle')),
                      ],
                      onChanged: (value) => setState(() {
                            audience = value ?? 'PRIVATE';
                            selectedCircleId = null;
                          })),
                  if (audience == 'CIRCLE')
                    DropdownButtonFormField<int>(
                        initialValue: selectedCircleId,
                        decoration:
                            const InputDecoration(labelText: 'Select circle'),
                        items: availableCircles
                            .map((circle) => DropdownMenuItem(
                                value: circle.id, child: Text(circle.name)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedCircleId = value)),
                  Row(children: [
                    TextButton.icon(
                        onPressed: loading ? null : pick,
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(selected?.name ?? 'Attach file')),
                    const Spacer(),
                    FilledButton(
                        onPressed: loading ||
                                (audience == 'CIRCLE' &&
                                    selectedCircleId == null)
                            ? null
                            : publish,
                        child: Text(audience == 'PRIVATE'
                            ? 'Save privately'
                            : 'Share entry'))
                  ])
                ]))),
        if (error.isNotEmpty)
          Padding(
              padding: const EdgeInsets.all(8),
              child: Text(error,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        if (loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator())),
        ...posts.map((p) => _post(p))
      ]));
  Future<void> editPost(Map<String, dynamic> post) async {
    final controller =
        TextEditingController(text: (post['caption'] ?? '').toString());
    final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Edit post'),
                content: TextField(
                    controller: controller,
                    maxLines: 4,
                    maxLength: 4000,
                    autofocus: true),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Save'))
                ]));
    controller.dispose();
    if (value == null) return;
    try {
      await widget.api.updateSocialPost((post['id'] as num).toInt(), value);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> sharePost(Map<String, dynamic> post) async {
    try {
      final values =
          await Future.wait([widget.api.relationships(), widget.api.circles()]);
      final relationships = values[0] as List<Relationship>;
      final circles = values[1] as List<CircleModel>;
      if (!mounted) return;
      String type = 'DIRECT', target = '';
      final note = TextEditingController();
      final send = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => StatefulBuilder(
              builder: (context, setModal) => Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Share post',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'DIRECT', label: Text('Person')),
                          ButtonSegment(value: 'CIRCLE', label: Text('Circle'))
                        ],
                        selected: {
                          type
                        },
                        onSelectionChanged: (value) => setModal(() {
                              type = value.first;
                              target = '';
                            })),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        initialValue: target.isEmpty ? null : target,
                        decoration: InputDecoration(
                            labelText: type == 'DIRECT' ? 'Person' : 'Circle'),
                        items: type == 'DIRECT'
                            ? relationships
                                .where((item) =>
                                    item.person.accountStatus == 'ACTIVE' &&
                                    item.person.identityType != 'MANAGED')
                                .map((item) => DropdownMenuItem(
                                    value: '${item.person.id}',
                                    child: Text(item.person.displayName)))
                                .toList()
                            : circles
                                .map((item) => DropdownMenuItem(
                                    value: '${item.id}',
                                    child: Text(item.name)))
                                .toList(),
                        onChanged: (value) => setModal(() => target = value!)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: note,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                            labelText: 'Message (optional)')),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: target.isEmpty
                                ? null
                                : () => Navigator.pop(context, true),
                            child: const Text('Share post')))
                  ]))));
      if (send == true) {
        await widget.api.shareSocialPost(
            (post['id'] as num).toInt(), type, int.parse(target), note.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post shared successfully.')));
        }
      }
      note.dispose();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> reportPost(Map<String, dynamic> post) async {
    String reason = 'SPAM';
    final details = TextEditingController();
    final submit = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
            builder: (context, setModal) => Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Report post',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                      initialValue: reason,
                      decoration: const InputDecoration(labelText: 'Reason'),
                      items: const [
                        DropdownMenuItem(
                            value: 'HARASSMENT', child: Text('Harassment')),
                        DropdownMenuItem(value: 'SPAM', child: Text('Spam')),
                        DropdownMenuItem(
                            value: 'IMPERSONATION',
                            child: Text('Impersonation')),
                        DropdownMenuItem(
                            value: 'PRIVACY', child: Text('Privacy violation')),
                        DropdownMenuItem(
                            value: 'ILLEGAL_CONTENT',
                            child: Text('Illegal content')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other'))
                      ],
                      onChanged: (value) => setModal(() => reason = value!)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: details,
                      maxLength: 2000,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Additional details (optional)')),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Submit report')))
                ]))));
    if (submit == true) {
      try {
        await widget.api.reportContent(
            reportedUserId: (post['authorUserId'] as num).toInt(),
            entityType: 'SOCIAL_POST',
            entityId: (post['id'] as num).toInt(),
            reason: reason,
            details: details.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report submitted for review.')));
        }
      } catch (e) {
        if (mounted) setState(() => error = '$e');
      }
    }
    details.dispose();
  }

  Future<void> showMyReports() async {
    try {
      final reports = await widget.api.myReports();
      if (!mounted) return;
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => FractionallySizedBox(
              heightFactor: .82,
              child: Column(children: [
                const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('My reports',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900)))),
                Expanded(
                    child: reports.isEmpty
                        ? const Center(child: Text('No reports submitted yet.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: reports.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final report = reports[index];
                              final status =
                                  report['status']?.toString() ?? 'OPEN';
                              return Card(
                                  child: ListTile(
                                      leading: Icon(status == 'RESOLVED'
                                          ? Icons.check_circle_outline_rounded
                                          : status == 'DISMISSED'
                                              ? Icons.remove_circle_outline
                                              : Icons.flag_outlined),
                                      title: Text((report['reason'] ?? 'Report')
                                          .toString()
                                          .replaceAll('_', ' ')),
                                      subtitle: Text(
                                          '${report['entityType'] ?? 'Account'}${report['entityId'] == null ? '' : ' #${report['entityId']}'}\n$status${report['moderatorNotes'] == null ? '' : '\n${report['moderatorNotes']}'}'),
                                      isThreeLine: true));
                            }))
              ])));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Widget _post(Map<String, dynamic> p) {
    final id = (p['id'] as num).toInt();
    final media = p['mediaUrl']?.toString();
    final type = p['mediaType']?.toString() ?? '';
    final comments = (p['comments'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return Card(
        margin: const EdgeInsets.only(top: 12),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListTile(
              leading: CircleAvatar(
                  child: Text((p['authorName'] ?? '?')
                      .toString()
                      .substring(0, 1)
                      .toUpperCase())),
              title: Text(p['authorName']?.toString() ?? ''),
              subtitle: Text(p['audience'] == 'RELATIONSHIPS'
                  ? 'Relationships'
                  : p['audience']?.toString() ?? ''),
              trailing: p['mine'] == true
                  ? PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          await editPost(p);
                        } else if (action == 'delete') {
                          final confirmed = await _confirmDestructiveAction(
                              context,
                              title: 'Delete post?',
                              message:
                                  'This diary post, its attachment, reactions, and comments will no longer appear in the feed. This action cannot be undone.',
                              confirmLabel: 'Delete post');
                          if (!confirmed) return;
                          await widget.api.deleteSocialPost(id);
                          await load();
                        }
                      },
                      itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'edit', child: Text('Edit post')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete post'))
                          ])
                  : null),
          if ((p['caption'] ?? '').toString().isNotEmpty)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(p['caption'].toString())),
          if (media != null && type.startsWith('image/'))
            FutureBuilder<Uint8List>(
                future: widget.api.socialMedia(media),
                builder: (_, snap) => snap.hasData
                    ? _FeedImageAttachment(
                        bytes: snap.data!,
                        name: p['mediaName']?.toString() ?? 'Image')
                    : const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()))),
          if (media != null && !type.startsWith('image/'))
            ListTile(
                leading: Icon(type.startsWith('video/')
                    ? Icons.video_file_outlined
                    : Icons.attach_file),
                title: Text(p['mediaName']?.toString() ?? 'Attachment'),
                subtitle: Text(type.startsWith('video/')
                    ? 'Video attachment'
                    : 'Shared attachment')),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                TextButton.icon(
                    onPressed: () async {
                      await widget.api.toggleSocialLike(id);
                      await load();
                    },
                    icon: Icon(
                        p['likedByMe'] == true
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: p['likedByMe'] == true ? Colors.pink : null),
                    label: Text('${p['likeCount'] ?? 0}')),
                IconButton(
                    tooltip: p['savedByMe'] == true ? 'Unsave' : 'Save post',
                    onPressed: () async {
                      await widget.api.toggleSocialSave(id);
                      await load();
                    },
                    icon: Icon(p['savedByMe'] == true
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded)),
                IconButton(
                    tooltip: 'Share post',
                    onPressed: () => sharePost(p),
                    icon: const Icon(Icons.send_outlined)),
                if (p['mine'] != true)
                  IconButton(
                      tooltip: 'Report post',
                      onPressed: () => reportPost(p),
                      icon: const Icon(Icons.flag_outlined)),
                const Spacer(),
                Text('${p['commentCount'] ?? 0} comments')
              ])),
          ...comments.map((c) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Row(children: [
                Expanded(child: Text('${c['authorName']}: ${c['message']}')),
                if (c['mine'] == true || p['mine'] == true)
                  IconButton(
                      tooltip: 'Delete comment',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () async {
                        final confirmed = await _confirmDestructiveAction(
                            context,
                            title: 'Delete comment?',
                            message:
                                'This comment will be permanently removed from the conversation. This action cannot be undone.',
                            confirmLabel: 'Delete comment');
                        if (!confirmed) return;
                        await widget.api
                            .deleteSocialComment(id, (c['id'] as num).toInt());
                        await load();
                      })
              ]))),
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: comment,
                        decoration: const InputDecoration(
                            hintText: 'Write a comment…', isDense: true))),
                IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      if (comment.text.trim().isEmpty) return;
                      await widget.api
                          .addSocialComment(id, comment.text.trim());
                      comment.clear();
                      await load();
                    })
              ]))
        ]));
  }
}

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  List<CircleModel>? circles;
  Map<int, int> unread = {};
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait<dynamic>(
          [widget.api.circles(), widget.api.circleUnreadCounts()]);
      final data = values[0] as List<CircleModel>;
      final counts = values[1] as Map<int, int>;
      if (mounted) {
        setState(() {
          circles = data;
          unread = counts;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
          onPressed: create,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New circle')),
      body: RefreshIndicator(
          onRefresh: load,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
                child: _PageHeader(
                    eyebrow: 'MY GROUPS',
                    title: 'Circles',
                    subtitle: 'Private spaces for the people who matter.',
                    action: IconButton.filledTonal(
                        onPressed: load,
                        icon: const Icon(Icons.refresh_rounded)))),
            if (error != null)
              SliverFillRemaining(child: _ErrorState(error!, retry: load))
            else if (circles == null)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  sliver: SliverList.separated(
                      itemCount: circles!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final circle = circles![i];
                        return Card(
                            child: ListTile(
                                contentPadding: const EdgeInsets.all(14),
                                leading: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: AppTheme.primary,
                                    child: Text(circle.name.characters.first,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900))),
                                title: Text(circle.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900)),
                                subtitle: Text(
                                    '${circle.members.length} members · ${circle.currentUserAdmin ? 'Admin' : 'Member'}\n${circle.description}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                isThreeLine: true,
                                trailing: (unread[circle.id] ?? 0) > 0
                                    ? Badge(
                                        label: Text(
                                            (unread[circle.id] ?? 0) > 99
                                                ? '99+'
                                                : '${unread[circle.id]}'),
                                        child: const Icon(
                                            Icons.chevron_right_rounded))
                                    : const Icon(Icons.chevron_right_rounded),
                                onTap: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => CircleChatScreen(
                                              api: widget.api,
                                              circle: circle)));
                                  await load();
                                }));
                      }))
          ])));
  Future<void> create() async {
    final name = TextEditingController(), description = TextEditingController();
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Create a circle'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Circle name')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: description,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 2)
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Create'))
                ]));
    if (result == true && name.text.trim().isNotEmpty) {
      await widget.api.createCircle(name.text.trim(), description.text.trim());
      await load();
    }
  }
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final query = TextEditingController();
  List<Person> results = [];
  bool loading = false;
  String? error;
  Future<void> search() async {
    if (query.text.trim().isEmpty) return;
    setState(() => loading = true);
    try {
      results = await widget.api.search(query.text.trim());
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(slivers: [
        const SliverToBoxAdapter(
            child: _PageHeader(
                eyebrow: 'DISCOVER',
                title: 'Find people',
                subtitle: 'Search by name, mobile number or location.')),
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchBar(
                    controller: query,
                    hintText: 'Search CircleNet…',
                    leading: const Icon(Icons.search),
                    trailing: [
                      IconButton(
                          onPressed: loading ? null : search,
                          icon: loading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.arrow_forward_rounded))
                    ],
                    onSubmitted: (_) => search()))),
        if (error != null)
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(error!,
                      style: const TextStyle(
                          color: Color(0xFFB4233C),
                          fontWeight: FontWeight.w700))))
        else
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final person = results[i];
                    return Card(
                        child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: _Avatar(person),
                            title: Text(person.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            subtitle: Text(
                                person.location ?? 'Location not provided'),
                            trailing: FilledButton.tonal(
                                onPressed: () => add(person),
                                child: const Text('Add'))));
                  }))
      ]);
  Future<void> add(Person person) async {
    String relation = 'Friend', visibility = 'FRIENDS';
    final ok = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
            builder: (context, setModal) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Add ${person.displayName}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField(
                      initialValue: relation,
                      decoration:
                          const InputDecoration(labelText: 'Relationship'),
                      items: [
                        'Friend',
                        'Spouse',
                        'Parent',
                        'Child',
                        'Sibling',
                        'Brother',
                        'Sister',
                        'Colleague',
                        'Relative'
                      ]
                          .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) => setModal(() => relation = v!)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                      initialValue: visibility,
                      decoration:
                          const InputDecoration(labelText: 'Who can view'),
                      items: const [
                        DropdownMenuItem(
                            value: 'FRIENDS', child: Text('Friends')),
                        DropdownMenuItem(
                            value: 'RELATIVES', child: Text('Relatives')),
                        DropdownMenuItem(
                            value: 'COLLEAGUES', child: Text('Colleagues')),
                        DropdownMenuItem(value: 'PUBLIC', child: Text('Public'))
                      ],
                      onChanged: (v) => setModal(() => visibility = v!)),
                  const SizedBox(height: 18),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Add relationship'))
                ]))));
    if (ok == true) {
      try {
        await widget.api.addRelationship(person, relation, visibility);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${person.displayName} added to your network.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen(
      {super.key, required this.api, required this.onDataChanged});
  final CircleNetApi api;
  final VoidCallback onDataChanged;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfileModel? profile;
  String? error;
  bool saving = false;
  final fields = <String, TextEditingController>{};
  final definitions = const [
    ('firstName', 'First name'),
    ('surname', 'Surname'),
    ('bio', 'About me'),
    ('phoneNumber', 'Mobile number'),
    ('email', 'Email'),
    ('location', 'Location'),
    ('addressLine1', 'Address'),
    ('city', 'City'),
    ('state', 'State'),
    ('country', 'Country'),
    ('linkedin', 'LinkedIn'),
    ('instagram', 'Instagram'),
    ('highestQualification', 'Highest qualification'),
    ('institution', 'Institution'),
    ('employer', 'Employer'),
    ('jobTitle', 'Job title')
  ];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.api.profile();
      for (final item in definitions) {
        fields[item.$1] = TextEditingController(text: value.value(item.$1));
      }
      if (mounted) setState(() => profile = value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: _PageHeader(
                eyebrow: 'MY IDENTITY',
                title: 'Profile',
                subtitle: 'Personal, contact, education and work details.',
                action: IconButton.filled(
                    onPressed: saving || profile == null ? null : save,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded)))),
        if (error != null)
          SliverFillRemaining(child: _ErrorState(error!, retry: load))
        else if (profile == null)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
              sliver: SliverList.list(children: [
                Card(
                    child: ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.auto_awesome_rounded)),
                        title: const Text('AI Contact Organizer',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text(
                            'Optional: review AI suggestions for relationships and circles. Nothing is added without confirmation.'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ContactOrganizerScreen(api: widget.api)));
                          if (changed == true) widget.onDataChanged();
                        })),
                Card(
                    child: ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.shield_outlined)),
                        title: const Text('Privacy & blocked accounts',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text(
                            'Review and unblock accounts you have blocked.'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    BlockedAccountsScreen(api: widget.api))))),
                const SizedBox(height: 12),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          CircleAvatar(
                              radius: 48,
                              backgroundColor: const Color(0xFFE9E4FF),
                              backgroundImage: profile!
                                      .value('profilePhoto')
                                      .isNotEmpty
                                  ? NetworkImage(profile!.value('profilePhoto'))
                                  : null,
                              child: profile!.value('profilePhoto').isEmpty
                                  ? const Icon(Icons.person_rounded,
                                      size: 44, color: AppTheme.primary)
                                  : null),
                          const SizedBox(height: 10),
                          const Text(
                              'Your profile photo is shared according to your privacy settings.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFF718096), fontSize: 12))
                        ]))),
                const SizedBox(height: 12),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          for (final item in definitions) ...[
                            TextField(
                                controller: fields[item.$1],
                                maxLines: item.$1 == 'bio' ? 3 : 1,
                                keyboardType: item.$1 == 'email'
                                    ? TextInputType.emailAddress
                                    : item.$1 == 'phoneNumber'
                                        ? TextInputType.phone
                                        : TextInputType.text,
                                decoration:
                                    InputDecoration(labelText: item.$2)),
                            const SizedBox(height: 10)
                          ]
                        ])))
              ]))
      ]);
  Future<void> save() async {
    setState(() => saving = true);
    try {
      final data = Map<String, dynamic>.from(profile!.data);
      for (final item in definitions) {
        data[item.$1] = fields[item.$1]!.text.trim();
      }
      profile = await widget.api.saveProfile(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.api.blockedUsers();
      if (mounted) {
        setState(() {
          items = value;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Blocked accounts')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _ErrorState(error!, retry: load)
              : items.isEmpty
                  ? const Center(child: Text('No blocked accounts.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return Card(
                            child: ListTile(
                                leading: const CircleAvatar(
                                    child: Icon(Icons.person_off_outlined)),
                                title: Text(item['displayName']?.toString() ??
                                    'Account'),
                                subtitle: const Text(
                                    'Cannot discover, message, or view your shared content'),
                                trailing: TextButton(
                                    onPressed: () async {
                                      final confirmed =
                                          await _confirmDestructiveAction(
                                              context,
                                              title: 'Unblock this account?',
                                              message:
                                                  '${item['displayName'] ?? 'This account'} will be able to discover you and interact with content according to your privacy settings again.',
                                              confirmLabel: 'Unblock account');
                                      if (!confirmed) return;
                                      await widget.api.unblockUser(
                                          (item['userId'] as num).toInt());
                                      await load();
                                    },
                                    child: const Text('Unblock'))));
                      }));
}

class ContactOrganizerScreen extends StatefulWidget {
  const ContactOrganizerScreen({super.key, required this.api});
  final CircleNetApi api;
  @override
  State<ContactOrganizerScreen> createState() => _ContactOrganizerScreenState();
}

class _ContactOrganizerScreenState extends State<ContactOrganizerScreen> {
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> suggestions = [];
  final TextEditingController emailController = TextEditingController();
  static const relationshipTypes = [
    'Mother',
    'Father',
    'Wife',
    'Husband',
    'Son',
    'Daughter',
    'Brother',
    'Sister',
    'Grandmother',
    'Grandfather',
    'Granddaughter',
    'Grandson',
    'Aunt',
    'Uncle',
    'Niece',
    'Nephew',
    'Cousin',
    'Guardian',
    'Relative',
    'Friend',
    'Colleague',
    'Other'
  ];

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('AI Contact Organizer')),
      body: SafeArea(
          child: loading
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Analyzing contact names and organizations…')
                ]))
              : suggestions.isEmpty
                  ? consentView()
                  : reviewView()));

  Widget consentView() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Icon(Icons.contact_phone_rounded,
            size: 60, color: AppTheme.primary),
        const SizedBox(height: 16),
        Text('Organize contacts with AI',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text(
            'CircleNet reads your phonebook only after permission. Raw contacts are not retained during analysis. You review every relationship and circle before anything is added.',
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        const Card(
            child: Padding(
                padding: EdgeInsets.all(14),
                child: Column(children: [
                  ListTile(
                      leading: Icon(Icons.lock_outline_rounded),
                      title: Text('Explicit permission'),
                      subtitle: Text(
                          'You can deny or revoke contact access at any time.')),
                  ListTile(
                      leading: Icon(Icons.rule_rounded),
                      title: Text('Review required'),
                      subtitle: Text(
                          'AI suggestions never modify your tree automatically.')),
                  ListTile(
                      leading: Icon(Icons.skip_next_rounded),
                      title: Text('Completely optional'),
                      subtitle:
                          Text('Skip now and use it later from Profile.')),
                ]))),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w800))),
        const SizedBox(height: 16),
        TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
                labelText: 'Email containing your contacts',
                hintText: 'name@gmail.com or name@outlook.com')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
                  onPressed: () => connectProvider('google'),
                  icon: const Icon(Icons.contact_mail_outlined),
                  label: const Text('Google'))),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: () => connectProvider('microsoft'),
                  icon: const Icon(Icons.business_outlined),
                  label: const Text('Outlook')))
        ]),
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'CircleNet opens the provider consent page with read-only contact access. Your email password is never requested or stored.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF718096)))),
        const SizedBox(height: 12),
        const Row(children: [
          Expanded(child: Divider()),
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('OR USE THIS DEVICE')),
          Expanded(child: Divider())
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: readAndAnalyze,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Allow and analyze contacts')),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip for now')),
      ]);

  Future<void> connectProvider(String provider) async {
    final email = emailController.text.trim();
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      setState(() => error = 'Enter a valid Google or Outlook email address.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final started = await widget.api.startContactOAuth(email, provider);
      final authorizationUrl =
          Uri.parse(started['authorizationUrl'].toString());
      final resultKey = started['resultKey'].toString();
      if (!await launchUrl(authorizationUrl,
          mode: LaunchMode.externalApplication)) {
        throw const CircleNetApiException(
            'The provider consent page could not be opened.');
      }
      List<Map<String, dynamic>>? result;
      for (var attempt = 0; attempt < 150 && mounted; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        try {
          result = await widget.api.contactOAuthResult(resultKey);
          break;
        } catch (_) {
          // A not-found response is expected until provider consent completes.
        }
      }
      if (result == null) {
        throw const CircleNetApiException(
            'Contact authorization timed out or was cancelled. Please try again.');
      }
      for (final item in result) {
        item['selected'] = item['phone'] != null || item['email'] != null;
      }
      if (mounted) setState(() => suggestions = result!);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget reviewView() => Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              Expanded(
                  child: Text(
                      '${suggestions.where((item) => item['selected'] == true).length} of ${suggestions.length} selected',
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              TextButton(
                  onPressed: () => setState(() {
                        for (final item in suggestions) {
                          item['selected'] = true;
                        }
                      }),
                  child: const Text('Select all')),
              TextButton(
                  onPressed: () => setState(() {
                        for (final item in suggestions) {
                          item['selected'] = false;
                        }
                      }),
                  child: const Text('Clear')),
            ])),
        if (error != null)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(error!,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w800))),
        Expanded(
            child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                itemCount: suggestions.length,
                itemBuilder: (_, index) {
                  final item = suggestions[index];
                  final circles = List<String>.from(
                      item['suggested_circles'] as List? ?? const []);
                  return Card(
                      child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: item['selected'] == true,
                                    onChanged: (value) => setState(() =>
                                        item['selected'] = value ?? false),
                                    title: Text(
                                        item['display_name']?.toString() ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    subtitle: Text(item['phone']?.toString() ??
                                        'No mobile number — will be skipped')),
                                DropdownButtonFormField<String>(
                                    initialValue: item['suggested_relationship']
                                        ?.toString(),
                                    decoration: const InputDecoration(
                                        labelText: 'Relationship'),
                                    items: relationshipTypes
                                        .map((value) => DropdownMenuItem(
                                            value: value, child: Text(value)))
                                        .toList(),
                                    onChanged: (value) => setState(() =>
                                        item['suggested_relationship'] =
                                            value)),
                                const SizedBox(height: 8),
                                TextFormField(
                                    initialValue: circles.join(', '),
                                    decoration: const InputDecoration(
                                        labelText: 'Suggested circles',
                                        helperText:
                                            'Separate circle names with commas'),
                                    onChanged: (value) =>
                                        item['suggested_circles'] = value
                                            .split(',')
                                            .map((part) => part.trim())
                                            .where((part) => part.isNotEmpty)
                                            .toList()),
                                const SizedBox(height: 6),
                                Text(
                                    '${((item['confidence'] as num?)?.toDouble() ?? 0) * 100 ~/ 1}% confidence • ${(item['reasons'] as List? ?? const []).join(' • ')}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF718096))),
                              ])));
                })),
        Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: accept,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Confirm selected suggestions'))))
      ]);

  Future<void> readAndAnalyze() async {
    if (kIsWeb) {
      setState(() =>
          error = 'Contact import is available in the Android and iOS apps.');
      return;
    }
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      setState(() => error = status.isPermanentlyDenied
          ? 'Contact access is disabled. Enable it in device settings, or skip this step.'
          : 'Contact permission was not granted. Nothing was uploaded.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final contacts = await FastContacts.getAllContacts();
      final payload = contacts
          .where((contact) => contact.displayName.trim().isNotEmpty)
          .map((contact) => {
                'contact_key': contact.id,
                'display_name': contact.displayName.trim(),
                'phones': contact.phones
                    .map((phone) => phone.number)
                    .where((value) => value.trim().isNotEmpty)
                    .toList(),
                'emails': contact.emails
                    .map((email) => email.address)
                    .where((value) => value.trim().isNotEmpty)
                    .toList(),
                'organization': contact.organization?.company ?? '',
                'job_title': contact.organization?.jobDescription ?? '',
                'labels': [
                  ...contact.phones.map((phone) => phone.label),
                  ...contact.emails.map((email) => email.label),
                  if ((contact.organization?.department ?? '').isNotEmpty)
                    contact.organization!.department
                ]
              })
          .take(2000)
          .toList();
      final result = await widget.api.analyzeContacts(payload);
      for (final item in result) {
        item['selected'] = item['phone'] != null || item['email'] != null;
      }
      if (mounted) setState(() => suggestions = result);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> accept() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final payload = suggestions
          .map((item) => {
                'displayName': item['display_name'],
                'phone': item['phone'],
                'email': item['email'],
                'relationship': item['suggested_relationship'],
                'circles': item['suggested_circles'],
                'selected': item['selected'] == true
              })
          .toList();
      final result = await widget.api.acceptContactSuggestions(payload);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
                  title: const Text('Contacts organized'),
                  content: Text(
                      '${result['peopleAdded']} people added and ${result['circleMembershipsAdded']} circle memberships created.${(result['skipped'] as List? ?? const []).isEmpty ? '' : '\n\nSkipped:\n${(result['skipped'] as List).join('\n')}'}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'))
                  ]));
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class DirectChatScreen extends StatelessWidget {
  const DirectChatScreen({super.key, required this.api, required this.person});
  final CircleNetApi api;
  final Person person;
  @override
  Widget build(BuildContext context) => ConversationScreen(
      title: person.displayName,
      subtitle: 'Private conversation',
      load: () => api.directMessages(person.id),
      send: (text, parentId) =>
          api.sendDirectMessage(person.id, text, replyToMessageId: parentId),
      sendAttachment: (text, bytes, name, parentId, onProgress) =>
          api.sendDirectAttachment(person.id, text, bytes, name,
              replyToMessageId: parentId, onProgress: onProgress),
      fetchAttachment: api.attachment,
      allowReplies: true,
      searchMessages: (query) => api.searchDirectMessages(person.id, query),
      editMessage: (id, value) => api.editDirectMessage(person.id, id, value),
      deleteMessage: (id) => api.deleteDirectMessage(person.id, id),
      reactMessage: (id, emoji) => api.reactDirectMessage(person.id, id, emoji),
      loadPresence: () => api.directPresence(person.id),
      setTyping: (typing) => api.setDirectTyping(person.id, typing),
      person: person);
}

class CircleChatScreen extends StatefulWidget {
  const CircleChatScreen({super.key, required this.api, required this.circle});
  final CircleNetApi api;
  final CircleModel circle;
  @override
  State<CircleChatScreen> createState() => _CircleChatScreenState();
}

class _CircleChatScreenState extends State<CircleChatScreen> {
  late CircleModel circle = widget.circle;

  @override
  Widget build(BuildContext context) => ConversationScreen(
          title: circle.name,
          subtitle: '${circle.members.length} members',
          load: () => widget.api.circleMessages(circle.id),
          send: (text, parentId) => widget.api
              .postCircleMessage(circle.id, text, parentMessageId: parentId),
          sendAttachment: (text, bytes, name, parentId, onProgress) =>
              widget.api.postCircleAttachment(circle.id, text, bytes, name,
                  parentMessageId: parentId, onProgress: onProgress),
          fetchAttachment: widget.api.attachment,
          allowReplies: true,
          editMessage: (id, value) =>
              widget.api.editCircleMessage(circle.id, id, value),
          deleteMessage: (id) => widget.api.deleteCircleMessage(circle.id, id),
          searchMessages: (query) =>
              widget.api.searchCircleMessages(circle.id, query),
          reactMessage: (id, emoji) =>
              widget.api.reactCircleMessage(circle.id, id, emoji),
          loadPresence: () => widget.api.circlePresence(circle.id),
          setTyping: (typing) => widget.api.setCircleTyping(circle.id, typing),
          actions: [
            IconButton(
                tooltip: 'Members',
                onPressed: showMembers,
                icon: const Icon(Icons.group_rounded)),
            if (circle.currentUserAdmin)
              IconButton(
                  tooltip: 'Circle settings',
                  onPressed: showSettings,
                  icon: const Icon(Icons.settings_rounded))
          ]);

  Future<void> showSettings() async {
    final name = TextEditingController(text: circle.name);
    final description = TextEditingController(text: circle.description);
    var permission = circle.postingPermission;
    final save = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
            builder: (context, setModal) => Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Circle settings',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: description,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Description')),
                  RadioGroup<String>(
                      groupValue: permission,
                      onChanged: (value) => setModal(() => permission = value!),
                      child: const Column(children: [
                        RadioListTile(
                            value: 'ALL_MEMBERS',
                            title: Text('All members can post')),
                        RadioListTile(
                            value: 'ADMINS_ONLY',
                            title: Text('Only admins can post'))
                      ])),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save settings')))
                ]))));
    if (save != true || name.text.trim().isEmpty) return;
    try {
      final updated = await widget.api.updateCircle(
          circle.id, name.text.trim(), description.text.trim(), permission);
      if (mounted) setState(() => circle = updated);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> showMembers() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
            builder: (context, setModal) => FractionallySizedBox(
                heightFactor: .78,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                      child: Row(children: [
                        Expanded(
                            child: Text('Members (${circle.members.length})',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900))),
                        if (circle.currentUserAdmin)
                          FilledButton.tonalIcon(
                              onPressed: () async {
                                await addMember(sheetContext);
                                setModal(() {});
                              },
                              icon: const Icon(Icons.person_add_rounded),
                              label: const Text('Add'))
                      ])),
                  Expanded(
                      child: ListView.builder(
                          itemCount: circle.members.length,
                          itemBuilder: (context, index) {
                            final member = circle.members[index];
                            return ListTile(
                                leading: _Avatar(member.person),
                                title: Text(member.person.displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                subtitle: Text(member.creator
                                    ? 'Creator - Admin'
                                    : member.admin
                                        ? 'Admin'
                                        : 'Member'),
                                trailing: !circle.currentUserAdmin ||
                                        member.creator
                                    ? null
                                    : PopupMenuButton<String>(
                                        onSelected: (action) async {
                                          try {
                                            if (action == 'remove') {
                                              final confirmed =
                                                  await _confirmDestructiveAction(
                                                      context,
                                                      title:
                                                          'Remove circle member?',
                                                      message:
                                                          '${member.person.displayName} will lose access to this circle and its private conversation. Their account and direct messages are not deleted.',
                                                      confirmLabel:
                                                          'Remove member');
                                              if (!confirmed) return;
                                            } else if (member.admin) {
                                              final confirmed =
                                                  await _confirmDestructiveAction(
                                                      context,
                                                      title:
                                                          'Remove administrator access?',
                                                      message:
                                                          '${member.person.displayName} will remain a circle member but will no longer be able to manage members, settings, or administrators.',
                                                      confirmLabel:
                                                          'Remove admin');
                                              if (!confirmed) return;
                                            }
                                            final updated = action == 'remove'
                                                ? await widget.api
                                                    .removeCircleMember(
                                                        circle.id,
                                                        member.person.id)
                                                : member.admin
                                                    ? await widget.api
                                                        .demoteCircleAdmin(
                                                            circle.id,
                                                            member.person.id)
                                                    : await widget.api
                                                        .promoteCircleAdmin(
                                                            circle.id,
                                                            member.person.id);
                                            if (mounted) {
                                              setState(() => circle = updated);
                                              setModal(() {});
                                            }
                                          } catch (e) {
                                            if (mounted) _showError(e);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                              PopupMenuItem(
                                                  value: 'admin',
                                                  child: Text(member.admin
                                                      ? 'Remove admin'
                                                      : 'Make admin')),
                                              const PopupMenuItem(
                                                  value: 'remove',
                                                  child: Text('Remove member'))
                                            ]));
                          }))
                ]))));
  }

  Future<void> addMember(BuildContext sheetContext) async {
    final relationships = await widget.api.relationships();
    final ids = circle.members.map((item) => item.person.id).toSet();
    final available = relationships
        .map((item) => item.person)
        .where((person) => !ids.contains(person.id))
        .toList();
    if (!mounted) return;
    final selected = await showDialog<Person>(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Add member'),
            content: SizedBox(
                width: 360,
                child: available.isEmpty
                    ? const Text('All your relationships are already members.')
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: available.length,
                        itemBuilder: (_, index) => ListTile(
                            leading: _Avatar(available[index]),
                            title: Text(available[index].displayName),
                            onTap: () =>
                                Navigator.pop(context, available[index]))))));
    if (selected == null) return;
    try {
      final updated = await widget.api.addCircleMember(circle.id, selected.id);
      if (mounted) setState(() => circle = updated);
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  void _showError(Object error) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString()),
          backgroundColor: const Color(0xFFB4233C)));
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.load,
      required this.send,
      required this.sendAttachment,
      required this.fetchAttachment,
      this.actions = const [],
      this.allowReplies = false,
      this.searchMessages,
      this.editMessage,
      this.deleteMessage,
      this.reactMessage,
      this.loadPresence,
      this.setTyping,
      this.person});
  final String title, subtitle;
  final Future<List<ConversationMessage>> Function() load;
  final Future<void> Function(String, int?) send;
  final Future<void> Function(
    String message,
    Uint8List bytes,
    String fileName,
    int? parentMessageId,
    void Function(double progress) onProgress,
  ) sendAttachment;
  final Future<Uint8List> Function(String) fetchAttachment;
  final List<Widget> actions;
  final bool allowReplies;
  final Future<List<ConversationMessage>> Function(String query)?
      searchMessages;
  final Future<void> Function(int id, String value)? editMessage;
  final Future<void> Function(int id)? deleteMessage;
  final Future<void> Function(int id, String emoji)? reactMessage;
  final Future<Map<String, dynamic>> Function()? loadPresence;
  final Future<void> Function(bool typing)? setTyping;
  final Person? person;
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final text = TextEditingController();
  Timer? messagePoller;
  List<ConversationMessage>? messages;
  String? error;
  bool sending = false;
  PlatformFile? selectedFile;
  ConversationMessage? replyingTo;
  double? uploadProgress;
  bool showingSearchResults = false;
  String? presenceText;
  @override
  void initState() {
    super.initState();
    load();
    text.addListener(typingChanged);
    messagePoller = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!showingSearchResults && !sending) load();
      loadPresence();
    });
    loadPresence();
  }

  @override
  void dispose() {
    messagePoller?.cancel();
    if (text.text.trim().isNotEmpty) widget.setTyping?.call(false);
    text.removeListener(typingChanged);
    text.dispose();
    super.dispose();
  }

  void typingChanged() => widget.setTyping?.call(text.text.trim().isNotEmpty);

  Future<void> loadPresence() async {
    if (widget.loadPresence == null) return;
    try {
      final value = await widget.loadPresence!();
      final typing = (value['typingUsers'] as List? ?? const [])
          .map((item) => (item as Map)['displayName'].toString())
          .toList();
      String label;
      if (typing.isNotEmpty) {
        label =
            '${typing.join(', ')} ${typing.length == 1 ? 'is' : 'are'} typing…';
      } else if (value['online'] == true && widget.person != null) {
        label = 'Online';
      } else if (value['lastActiveAt'] != null && widget.person != null) {
        final last = DateTime.tryParse(value['lastActiveAt'].toString());
        label = last == null ? widget.subtitle : 'Last active ${_time(last)}';
      } else {
        label = widget.subtitle;
      }
      if (mounted) setState(() => presenceText = label);
    } catch (_) {}
  }

  Future<void> load() async {
    try {
      final value = await widget.load();
      if (mounted) {
        setState(() {
          messages = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> search() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Search messages'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                        hintText: 'Words or attachment name')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      child: const Text('Search'))
                ]));
    controller.dispose();
    if (query == null) return;
    if (query.isEmpty) {
      showingSearchResults = false;
      await load();
      return;
    }
    try {
      final result = await widget.searchMessages!(query);
      if (mounted) {
        setState(() {
          messages = result;
          showingSearchResults = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> messageAction(ConversationMessage item, String action) async {
    try {
      if (action == 'reply') {
        setState(() => replyingTo = item);
        return;
      }
      if (action == 'edit') {
        final controller = TextEditingController(text: item.message);
        final value = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Edit message'),
                    content: TextField(controller: controller, maxLines: 3),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text.trim()),
                          child: const Text('Save'))
                    ]));
        controller.dispose();
        if (value != null) await widget.editMessage!(item.id, value);
      } else if (action == 'delete') {
        final confirmed = await _confirmDestructiveAction(context,
            title: 'Delete message?',
            message:
                'The message content and attachment will be removed from this conversation and replaced with a deleted-message notice. This action cannot be undone.',
            confirmLabel: 'Delete message');
        if (!confirmed) return;
        await widget.deleteMessage!(item.id);
      } else if (action.startsWith('react:')) {
        final emoji = action.substring(6);
        await widget.reactMessage!(
            item.id, item.myReaction == emoji ? '' : emoji);
      }
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> send() async {
    if (text.text.trim().isEmpty && selectedFile == null) return;
    setState(() => sending = true);
    try {
      if (selectedFile != null) {
        final bytes = selectedFile!.bytes;
        if (bytes == null) {
          throw const CircleNetApiException(
              'Could not read the selected file.');
        }
        await widget.sendAttachment(
          text.text.trim(),
          bytes,
          selectedFile!.name,
          replyingTo?.id,
          (progress) {
            if (mounted) setState(() => uploadProgress = progress);
          },
        );
      } else {
        await widget.send(text.text.trim(), replyingTo?.id);
      }
      text.clear();
      selectedFile = null;
      replyingTo = null;
      uploadProgress = null;
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> chooseAttachment() async {
    setState(() => error = null);
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'jfif',
        'png',
        'webp',
        'gif',
        'bmp',
        'tif',
        'tiff',
        'avif',
        'heic',
        'heif',
        'ico',
        'svg',
        'psd',
        'dng',
        'cr2',
        'nef',
        'arw',
        'glb',
        'gltf',
        'obj',
        'stl',
        'fbx',
        '3mf',
        'dae',
        'ply',
        'usdz',
        'blend',
        'mp4',
        'm4v',
        'mov',
        'avi',
        'mkv',
        'webm',
        'mpeg',
        'mpg',
        'ogv',
        '3gp',
        '3g2',
        'flv',
        'mp3',
        'wav',
        'm4a',
        'aac',
        'flac',
        'ogg',
        'oga',
        'opus',
        'amr',
        'aif',
        'aiff',
        'mid',
        'midi',
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt'
      ],
    );
    if (result == null) return;
    final file = result.files.single;
    if (file.size > 25 * 1024 * 1024) {
      setState(() => error =
          '“${file.name}” is ${_formatSize(file.size)}. Maximum attachment size is 25 MB.');
      return;
    }
    if (file.bytes == null) {
      setState(() =>
          error = 'Could not read “${file.name}”. Please choose it again.');
      return;
    }
    setState(() {
      selectedFile = file;
      uploadProgress = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Row(children: [
            if (widget.person != null) ...[
              _Avatar(widget.person!, radius: 19),
              const SizedBox(width: 10)
            ],
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
              Text(presenceText ?? widget.subtitle,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF718096)))
            ])
          ]),
          actions: [
            if (widget.searchMessages != null)
              IconButton(
                  tooltip: 'Search messages',
                  onPressed: search,
                  icon: const Icon(Icons.search_rounded)),
            ...widget.actions,
            IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))
          ]),
      body: Column(children: [
        if (error != null)
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFFFFE8EC),
              child: Text(error!,
                  style: const TextStyle(
                      color: Color(0xFFB4233C), fontWeight: FontWeight.w700))),
        Expanded(
            child: messages == null
                ? const Center(child: CircularProgressIndicator())
                : messages!.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Start the conversation.'))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(14),
                        itemCount: messages!.length,
                        itemBuilder: (context, index) {
                          final item = messages![messages!.length - 1 - index];
                          final parent = _messageById(item.parentMessageId);
                          return Align(
                              alignment: item.mine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.sizeOf(context).width *
                                              .78),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 9, 12, 7),
                                  decoration: BoxDecoration(
                                      color: item.mine
                                          ? const Color(0xFFE9E3FF)
                                          : Colors.white,
                                      border: Border.all(
                                          color: item.mine
                                              ? const Color(0xFFD3C7F4)
                                              : const Color(0xFFE0DCE8)),
                                      borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(
                                              item.mine ? 16 : 4),
                                          bottomRight: Radius.circular(
                                              item.mine ? 4 : 16))),
                                  child:
                                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    if (!item.mine)
                                      Text(item.authorName,
                                          style: const TextStyle(
                                              color: AppTheme.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900)),
                                    if (parent != null) ...[
                                      Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(
                                              top: 3, bottom: 6),
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: .62),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: const Border(
                                                  left: BorderSide(
                                                      color: AppTheme.primary,
                                                      width: 3))),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(parent.authorName,
                                                    style: const TextStyle(
                                                        color: AppTheme.primary,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w900)),
                                                Text(
                                                    parent.message
                                                            .trim()
                                                            .isNotEmpty
                                                        ? parent.message
                                                        : parent.attachmentName ??
                                                            'Attachment',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 11))
                                              ]))
                                    ],
                                    if (item.deleted)
                                      const Text('This message was deleted',
                                          style: TextStyle(
                                              color: Color(0xFF7F748D),
                                              fontStyle: FontStyle.italic))
                                    else if (item.message.isNotEmpty)
                                      Text(item.message,
                                          style: const TextStyle(
                                              color: AppTheme.ink,
                                              fontSize: 14)),
                                    if (item.hasAttachment) ...[
                                      if (item.message.isNotEmpty)
                                        const SizedBox(height: 8),
                                      _MessageAttachment(
                                        message: item,
                                        fetch: widget.fetchAttachment,
                                      ),
                                    ],
                                    const SizedBox(height: 3),
                                    Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_time(item.createdAt),
                                              style: const TextStyle(
                                                  color: Color(0xFF7F748D),
                                                  fontSize: 9)),
                                          if (item.editedAt != null)
                                            const Text(' · edited',
                                                style: TextStyle(
                                                    color: Color(0xFF7F748D),
                                                    fontSize: 9)),
                                          if (item.mine && item.readCount > 0)
                                            Text('  ✓✓ ${item.readCount}',
                                                style: const TextStyle(
                                                    color: AppTheme.primary,
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          if (widget.allowReplies)
                                            InkWell(
                                                onTap: () => setState(
                                                    () => replyingTo = item),
                                                child: const Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Icon(
                                                        Icons.reply_rounded,
                                                        size: 15,
                                                        color:
                                                            AppTheme.primary))),
                                          if (widget.reactMessage != null ||
                                              widget.editMessage != null ||
                                              widget.deleteMessage != null)
                                            PopupMenuButton<String>(
                                                tooltip: 'Message actions',
                                                padding: EdgeInsets.zero,
                                                onSelected: (value) =>
                                                    messageAction(item, value),
                                                itemBuilder: (_) => [
                                                      const PopupMenuItem(
                                                          value: 'reply',
                                                          child: Text('Reply')),
                                                      if (item.mine &&
                                                          !item.deleted)
                                                        const PopupMenuItem(
                                                            value: 'edit',
                                                            child:
                                                                Text('Edit')),
                                                      if (item.mine &&
                                                          !item.deleted)
                                                        const PopupMenuItem(
                                                            value: 'delete',
                                                            child:
                                                                Text('Delete')),
                                                      if (!item.deleted &&
                                                          widget.reactMessage !=
                                                              null)
                                                        for (final emoji in [
                                                          '👍',
                                                          '❤️',
                                                          '😂',
                                                          '😮',
                                                          '😢',
                                                          '🙏'
                                                        ])
                                                          PopupMenuItem(
                                                              value:
                                                                  'react:$emoji',
                                                              child: Text(
                                                                  '$emoji React'))
                                                    ])
                                        ]),
                                    if (item.reactions.isNotEmpty)
                                      Wrap(
                                          spacing: 4,
                                          children: item.reactions.entries
                                              .map((entry) => Chip(
                                                  label: Text(
                                                      '${entry.key} ${entry.value}'),
                                                  visualDensity:
                                                      VisualDensity.compact))
                                              .toList())
                                  ])));
                        })),
        if (replyingTo != null)
          Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
              color: const Color(0xFFF2EEFF),
              child: Row(children: [
                const Icon(Icons.reply_rounded,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 7),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Replying to ${replyingTo!.authorName}',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                      Text(
                          replyingTo!.message.isNotEmpty
                              ? replyingTo!.message
                              : replyingTo!.attachmentName ?? 'Attachment',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11))
                    ])),
                IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => replyingTo = null),
                    icon: const Icon(Icons.close_rounded, size: 18))
              ])),
        SafeArea(
            top: false,
            child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE5E0EF)))),
                child: Row(children: [
                  IconButton.filledTonal(
                      tooltip: 'Attach photo, video, audio, or document',
                      onPressed: sending ? null : chooseAttachment,
                      icon: const Icon(Icons.add_rounded)),
                  const SizedBox(width: 7),
                  Expanded(
                      child: TextField(
                          controller: text,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                              hintText: 'Message…', isDense: true))),
                  const SizedBox(width: 7),
                  IconButton.filled(
                      onPressed: sending ? null : send,
                      icon: sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded))
                ]))),
        if (selectedFile != null || uploadProgress != null)
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
              color: Colors.white,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedFile != null)
                      Row(children: [
                        const Icon(Icons.attach_file_rounded,
                            size: 18, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                          '${selectedFile!.name} · ${_formatSize(selectedFile!.size)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700),
                        )),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Remove attachment',
                          onPressed: sending
                              ? null
                              : () => setState(() => selectedFile = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ]),
                    if (uploadProgress != null)
                      LinearProgressIndicator(value: uploadProgress),
                  ]),
            ),
          )
      ]));
  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  ConversationMessage? _messageById(int? id) {
    if (id == null || messages == null) return null;
    for (final message in messages!) {
      if (message.id == id) return message;
    }
    return null;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _MessageAttachment extends StatefulWidget {
  const _MessageAttachment({required this.message, required this.fetch});
  final ConversationMessage message;
  final Future<Uint8List> Function(String) fetch;

  @override
  State<_MessageAttachment> createState() => _MessageAttachmentState();
}

class _MessageAttachmentState extends State<_MessageAttachment> {
  late final Future<Uint8List> bytes =
      widget.fetch(widget.message.attachmentUrl!);
  bool opening = false;

  @override
  Widget build(BuildContext context) {
    final type = widget.message.attachmentType ?? 'application/octet-stream';
    if (type.startsWith('image/')) {
      return FutureBuilder<Uint8List>(
        future: bytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorCard();
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 110,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return InkWell(
            onTap: () => _open(snapshot.data!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                snapshot.data!,
                width: 260,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fileCard(type),
              ),
            ),
          );
        },
      );
    }
    return _fileCard(type);
  }

  Widget _fileCard(String type) => FutureBuilder<Uint8List>(
        future: bytes,
        builder: (context, snapshot) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
              snapshot.hasData && !opening ? () => _open(snapshot.data!) : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 210),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .72),
              border: Border.all(color: const Color(0xFFD9D2E8)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE9E3FF),
                child: Icon(_icon(type), color: AppTheme.primary),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message.attachmentName ?? 'Attachment',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_label(type)} · ${_size(widget.message.attachmentSize)}',
                      style: const TextStyle(
                        color: Color(0xFF756B82),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (snapshot.hasError)
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFB4233C))
              else if (!snapshot.hasData || opening)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  type.startsWith('audio/') || type.startsWith('video/')
                      ? Icons.play_circle_fill_rounded
                      : Icons.open_in_new_rounded,
                  color: AppTheme.primary,
                ),
            ]),
          ),
        ),
      );

  Widget _errorCard() => const Text(
        'Attachment could not be loaded',
        style: TextStyle(color: Color(0xFFB4233C), fontWeight: FontWeight.w700),
      );

  Future<void> _open(Uint8List data) async {
    setState(() => opening = true);
    final opened = await openAttachmentBytes(
      data,
      widget.message.attachmentType ?? 'application/octet-stream',
      widget.message.attachmentName ?? 'attachment',
    );
    if (mounted) {
      setState(() => opening = false);
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Opening downloaded files on this device is coming next.'),
        ));
      }
    }
  }

  IconData _icon(String type) {
    if (type.startsWith('audio/')) return Icons.audiotrack_rounded;
    if (type.startsWith('video/')) return Icons.videocam_rounded;
    if (type == 'application/pdf') return Icons.picture_as_pdf_rounded;
    if (type.contains('sheet') || type.contains('excel')) {
      return Icons.table_chart_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  String _label(String type) {
    if (type.startsWith('audio/')) return 'Audio';
    if (type.startsWith('video/')) return 'Video';
    if (type == 'application/pdf') return 'PDF';
    return 'Document';
  }

  String _size(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
