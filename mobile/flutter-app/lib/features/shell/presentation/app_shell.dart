import 'workspace_navigation.dart';
import 'post_options_sheet.dart';
import 'renewals_screen.dart';
import 'package:myaaptha_mobile/core/contacts/contact_oauth_poll.dart';
import 'package:myaaptha_mobile/core/contacts/device_contact_access.dart';
import 'health_report_dialog.dart';
import 'moderation_queue_screen.dart';
import 'health_analysis_card.dart';
import 'package:myaaptha_mobile/core/widgets/info_help.dart';
import 'timeline_screen.dart';
import 'profile_media_card.dart';
import 'emergency_documents_screen.dart';
import 'follow_connections_screen.dart';
import 'chat_discovery_screen.dart';
import 'address_book_screen.dart';
import 'application_settings_screen.dart';
import 'help_chat_screen.dart';
import 'chain_network_view.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';

import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/core/platform/attachment_opener.dart';
import 'package:myaaptha_mobile/core/theme/app_theme.dart';
import 'package:myaaptha_mobile/features/auth/data/session_store.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  Map<String,dynamic> workspaceSettings = {};
  bool syncBusy = false;
  int index = 0;
  late final MyAapthaApi api = MyAapthaApi(widget.session);
  Timer? incomingTimer;
  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
  bool showingIncomingCall = false;
  int unreadNotifications = 0;
  int unreadMessages = 0;
  int unreadCircleMessages = 0;
  int syncVersion = 0;
  List<Widget> get pages => <Widget>[
        WorkspaceHub(key:const ValueKey('dashboard-hub'),title:'Dashboard',labels:const ['Overview','Life timeline','My profile','Trust center'],pages:[MobileDashboard(api:api),TimelineScreen(api:api),ProfileScreen(api:api,onDataChanged:refreshWorkspace),TrustCenterScreen(api:api)]),
        SocialFeedScreen(key: ValueKey('feed-$syncVersion'), api: api),
        WorkspaceHub(key:const ValueKey('messages-hub'),title:'Messages',labels:const ['Personal & groups','My circles','My contacts','Find people'],pages:[MessagesScreen(api:api),CirclesScreen(api:api),AddressBookScreen(api:api),DiscoverScreen(api:api)]),
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
            onSelectPrimaryPage: (value) => setState(() => index = value)),
        NetworkHome(api:api),
        HealthRecordsScreen(api:api),
        FinanceScreen(api:api),
        ProfileScreen(api:api,area:'Career',onDataChanged:refreshWorkspace),
        ProfileScreen(api:api,area:'Interests',onDataChanged:refreshWorkspace),
        WorkspaceHub(title:'Online Feed',labels:const ['Updates & thoughts','Following & followers'],pages:[SocialFeedScreen(api:api,online:true),FollowConnectionsScreen(api:api)])
      ];
  void refreshWorkspace(){if(mounted)setState(()=>syncVersion++);}
  final visitedPages=<int>{0};
  static const mobileDestinationIndexes = <int>[0,2,13,7];
  int get unreadChats => unreadMessages + unreadCircleMessages;
  List<NavigationDestination> get destinations => [
        const NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree_rounded),
            label: 'Dashboard'),
        const NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed_rounded),
            label: 'Diary & Memories'),
        NavigationDestination(
            icon: Badge(
                isLabelVisible: unreadChats > 0,
                label: Text(unreadChats > 99 ? '99+' : '$unreadChats'),
                child: const Icon(Icons.chat_bubble_outline_rounded)),
            selectedIcon: Badge(
                isLabelVisible: unreadChats > 0,
                label: Text(unreadChats > 99 ? '99+' : '$unreadChats'),
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
            label: 'Notifications'),
        const NavigationDestination(
            icon: Icon(Icons.person_search_outlined),
            selectedIcon: Icon(Icons.person_search_rounded),
            label: 'Search'),
        const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile'),
        const NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded),
            label: 'Tools'),
        const NavigationDestination(icon:Icon(Icons.account_tree_outlined),label:'Relationships'),
        const NavigationDestination(icon:Icon(Icons.monitor_heart_outlined),label:'Health'),
        const NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),label:'Finance'),
        const NavigationDestination(icon:Icon(Icons.work_outline),label:'Career'),
        const NavigationDestination(icon:Icon(Icons.interests_outlined),label:'Interests'),
        const NavigationDestination(icon:Icon(Icons.dynamic_feed_outlined),label:'Online Feed')
      ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadWorkspaceSettings();
    incomingTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => checkIncomingCalls());
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
    WidgetsBinding.instance.removeObserver(this);
    incomingTimer?.cancel();
    connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> loadWorkspaceSettings() async {
    try { final value=await api.applicationSettings(); if(mounted)setState(()=>workspaceSettings=value); } catch(_) {}
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed){loadWorkspaceSettings();checkIncomingCalls();}
  }
  Future<void> openSettings() async {
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>ApplicationSettingsScreen(api:api)));
    if(mounted)await loadWorkspaceSettings();
  }
  DateTime? lastWorkspaceSync;
  Future<void> checkIncomingCalls() async {
    if (!mounted || syncBusy || WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) return;
    syncBusy = true;
    try {
    if(lastWorkspaceSync==null||DateTime.now().difference(lastWorkspaceSync!).inSeconds>=15){
    lastWorkspaceSync=DateTime.now();
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
    }
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
    } finally { syncBusy = false; }
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
    final size=MediaQuery.sizeOf(context);
    final wide=size.width>=1000 && size.height>=650;
    visitedPages.add(index);
    final allPages=pages;
    final content=IndexedStack(index:index,children:[for(int i=0;i<allPages.length;i++)visitedPages.contains(i)?allPages[i]:const SizedBox.shrink()]);
    final selectedPrimary=workspacePrimaryIndexes.contains(index)?workspacePrimaryIndexes.indexOf(index):null;
    final theme=Theme.of(context);
    return Theme(data:theme.copyWith(visualDensity:workspaceSettings['compactLayout']==true?VisualDensity.compact:VisualDensity.standard),
      child:MediaQuery(data:MediaQuery.of(context).copyWith(disableAnimations:MediaQuery.of(context).disableAnimations||workspaceSettings['reducedMotion']==true),
      child:Scaffold(
        appBar:AppBar(surfaceTintColor:Colors.transparent,
          title:InkWell(borderRadius:BorderRadius.circular(24),onTap:()=>setState(()=>index=5),child:Container(
            padding:const EdgeInsets.symmetric(horizontal:14,vertical:11),decoration:BoxDecoration(color:theme.colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(24)),
            child:Row(children:[const Icon(Icons.search_rounded,size:22),const SizedBox(width:10),Expanded(child:Text('Search MyAaptha',overflow:TextOverflow.ellipsis,style:theme.textTheme.bodyLarge))]))),
          actions:[IconButton(tooltip:'Notifications',onPressed:()=>setState(()=>index=4),icon:Badge(isLabelVisible:unreadNotifications>0,label:Text(unreadNotifications>99?'99+':'$unreadNotifications'),child:const Icon(Icons.notifications_none_rounded))),IconButton(tooltip:'Settings',onPressed:openSettings,icon:const Icon(Icons.settings_outlined))]),
        drawer:wide?null:Drawer(child:SafeArea(child:Column(children:[
          const Padding(padding:EdgeInsets.all(24),child:_BrandMark()),
          Expanded(child:ListView(children:[for(final i in workspacePrimaryIndexes)ListTile(
            selected:index==i,leading:destinations[i].icon,title:Text(destinations[i].label),
            onTap:(){Navigator.pop(context);setState(()=>index=i);}),
            const Divider(),
            ListTile(leading:const Icon(Icons.tune_rounded),title:const Text('Account & tools'),onTap:(){Navigator.pop(context);setState(()=>index=7);}),
            ListTile(leading:const Icon(Icons.compare_arrows),title:const Text('Menu comparison'),onTap:(){Navigator.pop(context);openMenuComparison(context,api,widget.session,signOut);}),
          ])),ListTile(leading:const Icon(Icons.logout_rounded),title:const Text('Sign out'),onTap:signOut),
        ]))),
        body:SafeArea(child:wide?Row(children:[
          NavigationRail(scrollable:true,extended:true,selectedIndex:selectedPrimary,onDestinationSelected:(value)=>setState(()=>index=workspacePrimaryIndexes[value]),labelType:NavigationRailLabelType.none,
            leading:const Padding(padding:EdgeInsets.only(bottom:12),child:_BrandMark()),
            destinations:workspacePrimaryIndexes.map((i)=>NavigationRailDestination(icon:destinations[i].icon,selectedIcon:destinations[i].selectedIcon,label:Text(destinations[i].label))).toList(),trailing:Column(children:[IconButton(tooltip:'Account & tools',onPressed:()=>setState(()=>index=7),icon:const Icon(Icons.tune)),IconButton(tooltip:'Menu comparison',onPressed:()=>openMenuComparison(context,api,widget.session,signOut),icon:const Icon(Icons.compare_arrows))])),
          const VerticalDivider(width:1),Expanded(child:content),
          const VerticalDivider(width:1),SizedBox(width:60,child:Column(children:[const SizedBox(height:14),
            IconButton(tooltip:'Find people',onPressed:()=>setState(()=>index=5),icon:const Icon(Icons.person_search_outlined)),
            IconButton(tooltip:'Notifications',onPressed:()=>setState(()=>index=4),icon:const Icon(Icons.notifications_none_rounded)),
            IconButton(tooltip:'My profile',onPressed:()=>setState(()=>index=6),icon:const Icon(Icons.person_outline)),
            IconButton(tooltip:'Settings',onPressed:openSettings,icon:const Icon(Icons.tune_rounded)),
          ])),
        ]):content),
        bottomNavigationBar:wide?null:NavigationBar(
          selectedIndex:mobileDestinationIndexes.contains(index)?mobileDestinationIndexes.indexOf(index):mobileDestinationIndexes.length-1,
          onDestinationSelected:(value)=>setState(()=>index=mobileDestinationIndexes[value]),
          destinations:mobileDestinationIndexes.map((i)=>destinations[i]).toList()),
      )));
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
        Image.asset('assets/brand/myaaptha-logo.png', width: 48, height: 48),
        const SizedBox(height: 6),
        const Text('MyAaptha',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14))
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
  final MyAapthaApi api;
  final AuthTokenBundle session;
  final VoidCallback onSignOut;
  final ValueChanged<int> onSelectPrimaryPage;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _PageHeader(
              eyebrow: 'MYAAPTHA WORKSPACE',
              title: 'Account & tools',
              subtitle:
                  'The same workspace sections and labels used on the web.'),
          Card(child:ListTile(leading:const Icon(Icons.compare_arrows),title:const Text('Menu comparison'),onTap:()=>openMenuComparison(context,api,session,onSignOut))),
          const _MenuSection('ACCOUNT'),
          _moreTile(
              context,
              Icons.shield_outlined,
              'Privacy & settings',
              'Blocked accounts and privacy controls.',
              PrivacyCenterScreen(api: api)),
          _moreTile(
              context,
              Icons.devices_rounded,
              'Account sessions',
              'Review this login and sign out securely.',
              SessionScreen(session: session, onSignOut: onSignOut)),
          _moreTile(
              context,
              Icons.auto_awesome_outlined,
              'AI controls',
              'Review permissions, approvals and AI outcomes.',
              AiControlScreen(api: api)),
          _moreTile(context, Icons.help_outline, 'Ask MyAaptha',
              'Get answers about profiles, relations and broadcasts.',
              HelpChatScreen(api: api)),
          const _MenuSection('SAFETY & CONTROL'),
          _moreTile(context, Icons.flag_outlined, 'My reports',
              'Track reports you submitted.', ReportsScreen(api: api)),
          _moreTile(context, Icons.admin_panel_settings_outlined, 'Moderation',
              'Admin trust and safety queue.', ModerationScreen(api: api)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB4233C),
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: Color(0xFFEAF4F5)))),
        ],
      );

  Widget _moreTile(BuildContext context, IconData icon, String title,
          String subtitle, Widget destination) =>
      Card(
          child: ListTile(
              leading: Icon(icon, color: AppTheme.primary),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => Scaffold(
                          appBar: AppBar(title: Text(title)),
                          body: destination)))));
}

class _MenuSection extends StatelessWidget {
  const _MenuSection(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: Text(label,
            style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0)),
      );
}

class HealthRecordsScreen extends StatefulWidget {
  const HealthRecordsScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> with WidgetsBindingObserver {
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }
  Map<String, dynamic>? data;
  List<Map<String, dynamic>> docs = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final saved=await showDialog<bool>(context:context,barrierDismissible:false,builder:(_)=>HealthReportDialog(api:widget.api,documents:docs));
    if(saved==true&&mounted){await load();}
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
          HealthAnalysisCard(api:widget.api,onSaved:load),
          const Padding(
            padding: EdgeInsets.only(top: 18, bottom: 6),
            child: Text('Measurement trends',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
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
                                const TextStyle(fontWeight: FontWeight.w500)),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
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
  final MyAapthaApi api;
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with WidgetsBindingObserver {
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;
  // Finance API summaries and the web month selector use UTC calendar months.
  String get month => DateTime.now().toUtc().toIso8601String().substring(0, 7);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
                    'MyAaptha will read up to 200 recent messages on this device, select only messages that look financial, and upload those transaction messages to your private account for categorization. It will not import personal conversations. You can revoke SMS permission or delete transactions at any time.'),
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
      final messages = await const MethodChannel('myaaptha/sms')
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
          Card(child:ListTile(leading:const Icon(Icons.event_available_outlined),title:const Text('Bills & warranties'),subtitle:const Text('Expiry dates, receipts and renewal reminders'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>RenewalsScreen(api:widget.api))))),
          const SizedBox(height:12),
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
          Card(color: AppTheme.mint, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Income and spending', style: TextStyle(fontSize: 18,fontWeight:FontWeight.w500)),
            const SizedBox(height:12),
            ...['income','spending'].map((key) { final amount=(data?[key] as num?)?.toDouble() ?? 0; final maximum=math.max(1.0,math.max((data?['income'] as num?)?.toDouble() ?? 0,(data?['spending'] as num?)?.toDouble() ?? 0)); return Padding(padding:const EdgeInsets.only(bottom:12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${key == 'income' ? 'Income' : 'Spending'}: ${money(amount)}'), const SizedBox(height:6),
              LinearProgressIndicator(value:(amount/maximum).clamp(0.0,1.0),minHeight:12,color:key=='income'?const Color(0xFF3C8673):const Color(0xFFB27735),backgroundColor:Colors.white,borderRadius:BorderRadius.circular(8))
            ])); })
          ]))),
          const SizedBox(height: 12),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Spending by category',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w500)),
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
                                fontSize: 18, fontWeight: FontWeight.w500)),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
          ...transactions.map((x) => Card(
              child: ListTile(
                  leading: CircleAvatar(
                      child: Text('${x['category']}'.substring(0, 2))),
                  title: Text('${x['merchant'] ?? x['category']}'),
                  subtitle: Text('${x['category']} · ${x['source']}'),
                  trailing: Text(
                      '${x['direction'] == 'INCOME' ? '+' : '−'}${money(x['amount'])}',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: x['direction'] == 'INCOME'
                              ? Colors.green
                              : Colors.red)))))
        ]));
  }

  Widget _moneyCard(String title, dynamic value, Color color) => Card(
      color: title == 'Income' ? AppTheme.mint : title == 'Spending' ? AppTheme.peach : AppTheme.sky,
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            FittedBox(
                child: Text(money(value),
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: color,
                        fontSize: 14)))
          ])));
}

class PrivacyCenterScreen extends StatelessWidget {
  const PrivacyCenterScreen({super.key, required this.api});
  final MyAapthaApi api;
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
  final MyAapthaApi api;
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
          ...emergencies.map((x) => Card(
              child: ListTile(
                  title: Text('${x['requesterName']} → ${x['ownerName']}'),
                  subtitle: Text(
                      '${x['reason']}\n${x['approvals']}/${x['requiredApprovals']} approvals · ${x['status']}'),
                  isThreeLine: true,
                  trailing: x['canViewDocuments']==true
                      ? IconButton(tooltip:'View emergency documents',icon:const Icon(Icons.folder_open_outlined),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EmergencyDocumentsScreen(api:widget.api,requestId:(x['id'] as num).toInt()))))
                      : x['canDecide']==true
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
                                  fontSize: 18, fontWeight: FontWeight.w500))),
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
  final MyAapthaApi api;
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
 const ModerationScreen({super.key,required this.api});
 final MyAapthaApi api;
 @override Widget build(BuildContext context)=>ModerationQueueScreen(api:api);
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
                              fontWeight: FontWeight.w500, fontSize: 14)),
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

class AiControlScreen extends StatefulWidget {
  const AiControlScreen({super.key, required this.api});
  final MyAapthaApi api;

  @override
  State<AiControlScreen> createState() => _AiControlScreenState();
}

class _AiControlScreenState extends State<AiControlScreen> {
  bool loading = true;
  bool saving = false;
  bool aiEnabled = true;
  bool allowSensitiveData = false;
  bool allowPersonalization = false;
  int retentionDays = 90;
  String? status;
  List<Map<String, dynamic>> approvals = [];
  List<Map<String, dynamic>> executions = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await Future.wait([
        widget.api.aiPreferences(),
        widget.api.aiApprovals(),
        widget.api.aiExecutions()
      ]);
      final value = result[0] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        aiEnabled = value['aiEnabled'] == true;
        allowSensitiveData = value['allowSensitiveData'] == true;
        allowPersonalization = value['allowPersonalization'] == true;
        retentionDays = (value['activityRetentionDays'] as num?)?.toInt() ?? 90;
        approvals = (result[1] as List).cast<Map<String, dynamic>>();
        executions = (result[2] as List).cast<Map<String, dynamic>>();
      });
    } catch (exception) {
      if (mounted) setState(() => status = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      status = null;
    });
    try {
      final value = await widget.api.updateAiPreferences({
        'aiEnabled': aiEnabled,
        'allowSensitiveData': aiEnabled && allowSensitiveData,
        'allowPersonalization': aiEnabled && allowPersonalization,
        'activityRetentionDays': retentionDays,
      });
      if (!mounted) return;
      setState(() {
        aiEnabled = value['aiEnabled'] == true;
        allowSensitiveData = value['allowSensitiveData'] == true;
        allowPersonalization = value['allowPersonalization'] == true;
        status = 'AI controls saved. Server enforcement is active.';
      });
    } catch (exception) {
      if (mounted) setState(() => status = exception.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> decide(String approvalId, String decision) async {
    try {
      final updated = await widget.api.decideAiApproval(approvalId, decision);
      if (!mounted) return;
      setState(() {
        approvals = approvals
            .map((item) => item['id'] == approvalId ? updated : item)
            .toList();
        status = decision == 'APPROVED'
            ? 'Action approved. Approval does not mean it has executed.'
            : 'Action rejected.';
      });
    } catch (exception) {
      if (mounted) setState(() => status = exception.toString());
    }
  }

  Map<String, dynamic>? executionFor(String approvalId) {
    for (final execution in executions) {
      if (execution['approvalId'] == approvalId) return execution;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
          child: Column(children: [
        SwitchListTile(
            secondary: const Icon(Icons.auto_awesome_outlined,
                color: AppTheme.primary),
            title: const Text('Enable AI assistance'),
            subtitle: const Text('Master switch enforced by the API.'),
            value: aiEnabled,
            onChanged: saving
                ? null
                : (value) => setState(() {
                      aiEnabled = value;
                      if (!value) {
                        allowSensitiveData = false;
                        allowPersonalization = false;
                      }
                    })),
        const Divider(height: 1),
        SwitchListTile(
            title: const Text('Allow sensitive-data assistance'),
            subtitle: const Text(
                'For contacts, relationships, profiles, health and wealth. Each operation still asks for consent.'),
            value: allowSensitiveData,
            onChanged: !aiEnabled || saving
                ? null
                : (value) => setState(() => allowSensitiveData = value)),
        const Divider(height: 1),
        SwitchListTile(
            title: const Text('Allow personalization'),
            subtitle: const Text('Does not permit model training.'),
            value: allowPersonalization,
            onChanged: !aiEnabled || saving
                ? null
                : (value) => setState(() => allowPersonalization = value)),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: DropdownButtonFormField<int>(
                key: ValueKey(retentionDays),
                initialValue: retentionDays,
                decoration:
                    const InputDecoration(labelText: 'Activity retention'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Do not retain')),
                  DropdownMenuItem(value: 30, child: Text('30 days')),
                  DropdownMenuItem(value: 90, child: Text('90 days')),
                  DropdownMenuItem(value: 180, child: Text('180 days')),
                  DropdownMenuItem(value: 365, child: Text('365 days')),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => retentionDays = value ?? 90))),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
                onPressed: saving ? null : save,
                icon: const Icon(Icons.save_outlined),
                label: Text(saving ? 'Saving...' : 'Save AI controls'))),
      ])),
      if (status != null)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(status!)),
      const Padding(
          padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: Text('Agent approval inbox',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
      if (approvals.isEmpty) const Text('No agent actions need review.'),
      ...approvals.map((approval) {
        final execution = executionFor(approval['id'].toString());
        return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((approval['title'] ?? 'AI action').toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 14)),
                          const SizedBox(height: 6),
                          Text((approval['summary'] ?? '').toString()),
                          const SizedBox(height: 6),
                          Text(
                              '${approval['actionLevel'] ?? 'L2'} | ${approval['status'] ?? 'PENDING'}',
                              style: const TextStyle(color: AppTheme.muted)),
                          if (execution != null) ...[
                            const SizedBox(height: 4),
                            Text(
                                'Execution: ${execution['status'] ?? 'RUNNING'}',
                                style: const TextStyle(color: AppTheme.muted)),
                          ],
                          if (approval['status'] == 'PENDING') ...[
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: FilledButton.icon(
                                      onPressed: () => decide(
                                          approval['id'].toString(),
                                          'APPROVED'),
                                      icon: const Icon(Icons.check_rounded),
                                      label: const Text('Approve'))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: OutlinedButton.icon(
                                      onPressed: () => decide(
                                          approval['id'].toString(),
                                          'REJECTED'),
                                      icon: const Icon(Icons.close_rounded),
                                      label: const Text('Reject'))),
                            ])
                          ]
                        ]))));
      }),
      const Padding(
          padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: Text('Recent activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
      SizedBox(height: 480, child: AiActivityScreen(api: widget.api)),
    ]);
  }
}

class AiActivityScreen extends StatelessWidget {
  const AiActivityScreen({super.key, required this.api});
  final MyAapthaApi api;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
          future: api.aiActivity(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return _ErrorState('${snapshot.error}');
            final events = snapshot.data ?? [];
            if (events.isEmpty) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'No AI activity has been recorded for this account.')));
            }
            return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final event = events[index];
                  final capability = (event['capability'] ?? 'AI activity')
                      .toString()
                      .replaceAll('_', ' ')
                      .toLowerCase();
                  final consent = event['consentGranted'] == true
                      ? 'Consent granted'
                      : 'No sensitive consent required';
                  return Card(
                      child: ListTile(
                          leading: const Icon(Icons.auto_awesome_outlined,
                              color: AppTheme.primary),
                          title: Text(capability,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text('${event['purpose'] ?? ''}\n'
                              '${event['actionLevel'] ?? 'L0'} · $consent'),
                          isThreeLine: true,
                          trailing: Text(
                              (event['status'] ?? '').toString().toLowerCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: event['status'] == 'FAILED'
                                      ? const Color(0xFFB4233C)
                                      : AppTheme.primary))));
                });
          });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.api});
  final MyAapthaApi api;
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
    if (uri.path == '/finance') {
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>RenewalsScreen(api:widget.api)));
    } else if (uri.path == '/feed') {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => SocialFeedScreen(api: widget.api,online:true)));
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
                      color: Colors.red, fontWeight: FontWeight.w500))),
        Expanded(
            child:
                RefreshIndicator(onRefresh: load, child: _notificationList())),
      ]);
  Widget _notificationList() {
    if (items.isEmpty && !loading) {
      return ListView(children: const [
        SizedBox(height: 120),
        Icon(Icons.notifications_none_rounded,
            size: 52, color: Color(0xFF256F7B)),
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
              color: unread ? const Color(0xFFF4F7FA) : Colors.white,
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
                                    : const Color(0xFFF4F7FA),
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
                                              ? FontWeight.w500
                                              : FontWeight.w500,
                                          color: AppTheme.ink)),
                                  const SizedBox(height: 2),
                                  Text('${item['body']}',
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF59697D))),
                                  const SizedBox(height: 4),
                                  Text(_notificationTime(item['createdAt']),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF59697D)))
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
  final MyAapthaApi api;
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
                                    ?.copyWith(fontWeight: FontWeight.w500))),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close))
                      ]),
                      const Text('Delivery channels',
                          style: TextStyle(fontWeight: FontWeight.w500)),
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
                          style: TextStyle(fontWeight: FontWeight.w500)),
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
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: eyebrow.contains('MONEY') ? AppTheme.mint : eyebrow.contains('HEALTH') ? AppTheme.rose : AppTheme.lavender, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal:12,vertical:8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eyebrow,
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          InfoHelpLabel(title:title,message:subtitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w500, color: AppTheme.ink)),

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
      backgroundColor: const Color(0xFFF4F7FA),
      backgroundImage: person.profilePhoto?.isNotEmpty == true
          ? NetworkImage(person.profilePhoto!)
          : null,
      child: person.profilePhoto?.isNotEmpty == true
          ? null
          : Text(person.displayName.characters.first.toUpperCase(),
              style: TextStyle(
                  fontWeight: FontWeight.w500,
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
                size: 46, color: Color(0xFFB4233C)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFB4233C), fontWeight: FontWeight.w500)),
            if (retry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                  onPressed: retry, child: const Text('Try again'))
            ]
          ])));
}

class MobileDashboard extends StatefulWidget {
  const MobileDashboard({super.key,required this.api});
  final MyAapthaApi api;
  @override State<MobileDashboard> createState()=>_MobileDashboardState();
}
class _MobileDashboardState extends State<MobileDashboard>{
  late Future<List<Relationship>> relationships=widget.api.relationships();
  void open(String title,Widget page)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:Text(title)),body:page)));
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    const _PageHeader(eyebrow:'MYAAPTHA',title:'Dashboard',subtitle:'Your people, memories and conversations at a glance.'),
    FutureBuilder<List<Relationship>>(future:relationships,builder:(context,snapshot)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:snapshot.hasError?TextButton(onPressed:()=>setState(()=>relationships=widget.api.relationships()),child:const Text('Retry overview')):Text(snapshot.hasData?'${snapshot.data!.length} relationships':'Loading your overview...')))),
    Card(child:ListTile(leading:const Icon(Icons.account_tree_outlined),title:const Text('Relationship tree'),subtitle:const Text('Explore your tree and message selected levels'),trailing:const Icon(Icons.chevron_right),onTap:()=>open('Relationship tree',NetworkHome(api:widget.api)))),
    Card(child:ListTile(leading:const Icon(Icons.edit_note),title:const Text('Diary & memories'),onTap:()=>open('Diary & memories',SocialFeedScreen(api:widget.api)))),
    Card(child:ListTile(leading:const Icon(Icons.mail_outline),title:const Text('Messages'),onTap:()=>open('Messages',MessagesScreen(api:widget.api)))),
    Card(child:ListTile(leading:const Icon(Icons.timeline),title:const Text('Life timeline'),onTap:()=>open('Life timeline',TimelineScreen(api:widget.api)))),
  ]);
}

class NetworkHome extends StatefulWidget {
  const NetworkHome({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<NetworkHome> createState() => _NetworkHomeState();
}

class _NetworkHomeState extends State<NetworkHome> {
  List<Relationship>? items;
  UserProfileModel? profile;
  String treeView = 'tree';
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
                eyebrow: 'MY MYAAPTHA',
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
                  SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'tree',
                            icon: Icon(Icons.account_tree_rounded),
                            tooltip: 'Tree view'),
                        ButtonSegment(value: 'chain', icon: Icon(Icons.hub_outlined), tooltip: 'Chain explorer'),
                        ButtonSegment(
                            value: 'list',
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
        else if (treeView == 'chain')
          SliverFillRemaining(hasScrollBody: true, child: ChainNetworkView(relationships: items!, profile: profile, onDetails: (relation) => RelationshipTile(relationship: relation, api: widget.api, onRemoved: load).showConnect(context)))
        else if (treeView == 'tree')
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
  final MyAapthaApi api;
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
  int levels = 1;
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
            style: TextStyle(color: Color(0xFF59697D))),
        const SizedBox(height: 12),
        SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'HORIZONTAL',
                  label: Text('Level'),
                  icon: Icon(Icons.account_tree_rounded)),
              ButtonSegment(
                  value: 'VERTICAL',
                  label: Text('Branch'),
                  icon: Icon(Icons.vertical_align_bottom_rounded)),
              ButtonSegment(
                  value: 'LOCATION',
                  label: Text('Area'),
                  icon: Icon(Icons.location_on_outlined)),
            ],
            selected: {
              audienceType
            },
            onSelectionChanged: loading?null:(values) => setState(() {
                  audienceType = values.first;
                  levels = 1;
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
              onChanged: loading?null:(value) => setState(() {
                    anchorUserId = value;
                    preview = null;
                  })),
        if (audienceType != 'LOCATION') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(key:ValueKey('levels-$audienceType'),initialValue:levels,decoration:const InputDecoration(labelText:'Relationship levels'),items:[...List.generate(10,(i)=>DropdownMenuItem(value:i+1,child:Text('${i+1} ${i==0?'level':'levels'}'))),if(audienceType=='VERTICAL')const DropdownMenuItem(value:0,child:Text('Whole branch'))],onChanged:loading?null:(value)=>setState((){levels=value??1;preview=null;})),
          Text(audienceType=='HORIZONTAL'?'Only people exactly $levels generations below, through child relationships.':levels==0?'Starting person and the whole branch.':'Starting person plus up to $levels levels below.'),
        ],
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
                      color: Colors.red, fontWeight: FontWeight.w500))),
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
                                const TextStyle(fontWeight: FontWeight.w500)),
                        if ((preview!['excludedCount'] as num).toInt() > 0)
                          Text(
                              '${preview!['excludedCount']} managed, invited or inactive profiles excluded',
                              style: const TextStyle(
                                  color: Color(0xFF805B12), fontSize: 14)),
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
          anchorUserId: anchorUserId, levels:audienceType=='LOCATION'||levels==0?null:levels, location: locationController.text);
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
          levels:audienceType=='LOCATION'||levels==0?null:levels,
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
  final MyAapthaApi api;
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
            color: const Color(0xFFFFFFFF),
            border: Border.all(color: const Color(0xFFEAF4F5)),
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
                              fontSize: 14, fontWeight: FontWeight.w500))
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
      ..color = const Color(0xFF59697D)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = const Color(0xFF59697D);
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
              ..color = const Color(0xFFB4233C)
              ..strokeWidth = 2.4);
        _label(
            canvas,
            '♥',
            Offset((sourceCenter.dx + targetCenter.dx) / 2,
                (sourceCenter.dy + targetCenter.dy) / 2 - 9),
            color: const Color(0xFFB4233C));
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
      {Color color = const Color(0xFF256F7B)}) {
    final displayText =
        text.codeUnits.contains(226) ? String.fromCharCode(0x2665) : text;
    final painter = TextPainter(
        text: TextSpan(
            text: displayText,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w500)),
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
        ? const Color(0xFFFFF1F3)
        : gender == 'MALE'
            ? const Color(0xFF256F7B)
            : const Color(0xFF805B12);
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
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                          Text(relationship.type,
                              maxLines: 1,
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500))
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
                    colors: [Color(0xFF256F7B), Color(0xFF256F7B)]),
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
                              fontSize: 20,
                              fontWeight: FontWeight.w500))
                      : null),
              const SizedBox(height: 5),
              Text(name.isEmpty ? 'You' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const Text('You',
                  style: TextStyle(color: Colors.white70, fontSize: 14))
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
  final MyAapthaApi api;
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
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.ink)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 5, children: [
                          _Tag(relationship.type, const Color(0xFFEAF4F5),
                              const Color(0xFF17634E)),
                          _Tag(relationship.visibilityScope,
                              const Color(0xFFF4F7FA), const Color(0xFF256F7B)),
                          _Tag(
                              person.accountStatus == 'ACTIVE'
                                  ? 'Verified'
                                  : 'Not verified',
                              person.accountStatus == 'ACTIVE'
                                  ? const Color(0xFFEAF4F5)
                                  : const Color(0xFFEAF4F5),
                              person.accountStatus == 'ACTIVE'
                                  ? const Color(0xFF17634E)
                                  : const Color(0xFF805B12))
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
                            fontSize: 18, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text('Choose how you want to connect.',
                        style: TextStyle(color: Color(0xFF59697D))),
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
                        color: const Color(0xFF17634E),
                        onTap: () => relationship.person.canConnect
                            ? _startCall(context, 'AUDIO')
                            : _showCommunicationUnavailable(context)),
                    _ConnectAction(
                        icon: Icons.videocam_rounded,
                        label: 'Video call',
                        color: const Color(0xFFB4233C),
                        onTap: () => relationship.person.canConnect
                            ? _startCall(context, 'VIDEO')
                            : _showCommunicationUnavailable(context)),
                    const Divider(height: 22),
                    _ConnectAction(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Add relationship to this person',
                        color: const Color(0xFF17634E),
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
                  '${relationship.person.displayName} can receive messages and calls after activating their MyAaptha account. The communication options will remain available here.'),
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
                              fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text(
                          'This person will appear directly in ${relationship.person.displayName}â€™s family branch.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF59697D))),
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
                              fontSize: 18, fontWeight: FontWeight.w500)),
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
            '${relationship.person.displayName} will disappear from your relationship tree and circles will no longer use this relationship. Their MyAaptha account and your existing messages are not deleted.',
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
  final MyAapthaApi api;
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
      'MyAaptha member';

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final ice=await widget.api.callIceConfiguration();
      if(!mounted)return;
      await Future.wait(
          [localRenderer.initialize(), remoteRenderer.initialize()]);
      localStream = await navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': video});
      localRenderer.srcObject = localStream;
      peer = await createPeerConnection({'iceServers':ice['iceServers']});
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
          backgroundColor: const Color(0xFF15233B),
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
                    backgroundColor: const Color(0xFF256F7B),
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
                                fontSize: 24,
                                fontWeight: FontWeight.w500))),
              const SizedBox(height: 16),
              Text(personName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(error ?? phase,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: error == null
                          ? Colors.white70
                          : const Color(0xFFEAF4F5),
                      fontWeight: FontWeight.w500))
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
                      color: const Color(0xFFB4233C),
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
              color: foreground, fontSize: 14, fontWeight: FontWeight.w500)));
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
                color: const Color(0xFFF4F7FA),
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
                      style: TextStyle(color: Colors.white, fontSize: 14))
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
      backgroundColor: const Color(0xFF15233B),
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
                                  fontWeight: FontWeight.w500)),
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
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
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
  final MyAapthaApi api;
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  Future<void> findConversation() async {
    final target = await Navigator.push<ChatTarget>(context, MaterialPageRoute(builder: (_) => ChatDiscoveryScreen(api: widget.api)));
    if (target == null || !mounted) return;
    try {
      if (target.type == 'CIRCLE') {
        final groups = await widget.api.circles();
        final circle = groups.firstWhere((value) => value.id == target.id);
        if (!mounted) return;
        await Navigator.push(context, MaterialPageRoute(builder: (_) => CircleChatScreen(api: widget.api, circle: circle)));
      } else {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => DirectChatScreen(api: widget.api, person: Person(id: target.id, displayName: target.name, accountStatus: 'ACTIVE', identityType: 'ACCOUNT'))));
      }
      if (mounted) await load();
    } catch (e) { if (mounted) setState(() => error = '$e'); }
  }
  List<DirectConversation>? items;
  List<CircleConversation> circleItems=[];
  String? error;
  Timer? poller;
  bool? readReceipts;
  bool saving=false;
  String folder='inbox';
  List<Object> get visible {
    final result=<Object>[
      ...(items??[]).where((item)=>folder=='circles'?false:folder=='archived'?item.archived:!item.archived&&(folder!='unread'||item.unreadCount>0||item.markedUnread)),
      ...circleItems.where((item)=>folder!='archived'&&folder!='direct'&&(folder!='unread'||item.unreadCount>0))];
    DateTime date(Object item)=>item is DirectConversation?item.lastMessageAt:(item as CircleConversation).lastMessageAt??DateTime(1970);
    result.sort((a,b){final pinA=a is DirectConversation&&a.pinned;final pinB=b is DirectConversation&&b.pinned;return pinA!=pinB?(pinA?-1:1):date(b).compareTo(date(a));});
    return result;
  }
  Future<void> change(Future<void> Function() action) async {setState(()=>saving=true);try{await action();await load();}catch(e){if(mounted)setState(()=>error='$e');}finally{if(mounted)setState(()=>saving=false);}}
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
      final receipts = await widget.api.messagePreferences();
      final groups=await widget.api.circleConversations();
      if (mounted) {
        setState(() {
          items = value;
          circleItems=groups;
          readReceipts=receipts;
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
                eyebrow: 'MESSAGES',
                title: 'Messages',
                subtitle: 'Recent chats and unread messages.')),
        SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:OutlinedButton.icon(onPressed:saving?null:findConversation,icon:const Icon(Icons.search),label:const Text('New chat, group & message search')))),
        SliverToBoxAdapter(child:SwitchListTile(title:const Text('Share read receipts'),subtitle:const Text('When off, neither side sees direct-message read times. Unread counts still update.'),value:readReceipts??false,onChanged:readReceipts==null||saving?null:(value)async{final previous=readReceipts;setState((){saving=true;readReceipts=value;});try{await widget.api.saveMessagePreferences(value);}catch(e){if(mounted)setState((){readReceipts=previous;error='$e';});}finally{if(mounted)setState(()=>saving=false);}})),
        SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(16),child:Wrap(spacing:8,children:[for(final value in ['inbox','unread','direct','circles','archived']) ChoiceChip(label:Text(value=='inbox'?'Inbox':value=='unread'?'Unread':value=='direct'?'People':value=='circles'?'Groups & circles':'Archived'),selected:folder==value,onSelected:(_)=>setState(()=>folder=value))]))),
        const SliverToBoxAdapter(child:Padding(padding:EdgeInsets.symmetric(horizontal:16),child:Text('Archived chats stay archived. Muting stops message alerts until you unmute. Unread reminders do not undo read receipts.'))),
        if (error != null)
          SliverToBoxAdapter(child: _ErrorState(error!, retry: load)),
        if (items == null)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else if (visible.isEmpty)
          const SliverFillRemaining(
              child: Center(
                  child:
                      Text('No conversations in this view.')))
        else
          SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final entry = visible[index];
                if(entry is CircleConversation){return ListTile(leading:const CircleAvatar(child:Icon(Icons.groups_outlined)),title:Text(entry.name),subtitle:Text('Circle \u00b7 ${entry.lastMessage}',maxLines:1,overflow:TextOverflow.ellipsis),trailing:entry.unreadCount>0?Badge(label:Text('${entry.unreadCount}')):null,onTap:()async{
                  try{final groups=await widget.api.circles();final circle=groups.firstWhere((c)=>c.id==entry.id);if(!context.mounted)return;await Navigator.push(context,MaterialPageRoute(builder:(_)=>CircleChatScreen(api:widget.api,circle:circle)));await load();}catch(e){if(mounted)setState(()=>error='$e');}
                });}
                final item=entry as DirectConversation;
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
                    title: Text('${item.displayName}${item.muted?' (Muted)':''}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(item.lastMessage,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(mainAxisSize:MainAxisSize.min,children:[PopupMenuButton<String>(tooltip:'Chat actions',enabled:!saving,onSelected:(value)=>change(()=>widget.api.saveChatSettings(item.userId,archived:value=='archive'?!item.archived:null,muted:value=='mute'?!item.muted:null,markedUnread:value=='unread'?!item.markedUnread:null)),itemBuilder:(_)=>[
                      PopupMenuItem(value:'archive',child:Text(item.archived?'Unarchive':'Archive')),
                      PopupMenuItem(value:'mute',child:Text(item.muted?'Unmute':'Mute')),
                      PopupMenuItem(value:'unread',child:Text(item.markedUnread?'Clear unread reminder':'Mark unread')),
                    ]),IconButton(tooltip:item.pinned?'Unpin chat':'Pin chat',icon:Icon(item.pinned?Icons.push_pin:Icons.push_pin_outlined),onPressed:saving?null:()async{setState(()=>saving=true);try{await widget.api.pinConversation(item.userId,!item.pinned);await load();}catch(e){if(mounted)setState(()=>error='$e');}finally{if(mounted)setState(()=>saving=false);}}),(item.unreadCount > 0 || item.markedUnread)
                        ? Badge(
                            label: Text(item.unreadCount > 99
                                ? '99+'
                                : item.unreadCount>0?'${item.unreadCount}':'Unread'))
                        : Text(_time(item.lastMessageAt),
                            style: const TextStyle(fontSize: 14))]),
                    onTap: saving?null:() async {
                      if(item.markedUnread) {
                        try {await widget.api.saveChatSettings(item.userId,markedUnread:false);}catch(e){if(mounted)setState(()=>error='$e');return;}
                        if(!context.mounted)return;
                      }
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
  const SocialFeedScreen({super.key, required this.api, this.online=false});
  final bool online;
  final MyAapthaApi api;
  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  final caption = TextEditingController();
  final comment = TextEditingController();
  final commentFocus=<int,FocusNode>{};
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
    for(final focus in commentFocus.values){focus.dispose();}
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
          'docx',
          'xlsx',
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
                                  fontWeight: FontWeight.w500))),
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
                Text(savedOnly ? 'Saved moments' : widget.online?'Online Feed':'Diary & Memories',
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
        ...posts.where((p)=>widget.online||p['mine']==true).map((p) => _post(p))
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
                            fontSize: 18, fontWeight: FontWeight.w500)),
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
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
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
                                fontSize: 20, fontWeight: FontWeight.w500)))),
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

  Future<void> postOptions(Map<String,dynamic> p) async {
    final action=await showModalBottomSheet<String>(context:context,isScrollControlled:true,showDragHandle:true,builder:(_)=>PostOptionsSheet(post:p));
    if(action==null||!mounted)return;
    final id=(p['id'] as num).toInt();
    try{
      if(action.startsWith('reaction:')){final value=action.substring(9);await widget.api.reactSocialPost(id,value.isEmpty?null:value);await load();}
      else if(action=='pin'){await widget.api.pinSocialPost(id,p['pinned']!=true);await load();}
      else if(action=='star'){await widget.api.toggleSocialSave(id);await load();}
      else if(action=='forward'){await sharePost(p);}
      else if(action=='edit'){await editPost(p);}
      else if(action=='report'){await reportPost(p);}
      else if(action=='delete'){final yes=await _confirmDestructiveAction(context,title:'Delete post?',message:'This removes the post, attachment, reactions and comments for everyone who could view it.',confirmLabel:'Delete post');if(yes){await widget.api.deleteSocialPost(id);await load();}}
      else if(action=='copy'){await Clipboard.setData(ClipboardData(text:(p['caption']?.toString().isNotEmpty??false)?p['caption'].toString():p['mediaName']?.toString()??'Post $id'));if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Copied to clipboard.')));}
      else if(action=='reply'){commentFocus.putIfAbsent(id,()=>FocusNode()).requestFocus();}
      else if(action=='info'){await showDialog<void>(context:context,builder:(context)=>AlertDialog(title:const Text('Post info'),content:SingleChildScrollView(child:Text('Author: ${p['authorName']}\nCreated: ${p['createdAt']}\nUpdated: ${p['updatedAt']}\nAudience: ${p['audience']}\nReactions: ${p['likeCount']}\nComments: ${p['commentCount']}\nPinned for you: ${p['pinned']==true}\nStarred: ${p['savedByMe']==true}\n${p['mediaName']??''}')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))]));}
      else if(action=='ask'){final text='Help me understand this post. Do not take actions: ${p['caption']??'Attachment-only post'}';await Navigator.push(context,MaterialPageRoute(builder:(_)=>HelpChatScreen(api:widget.api,initialQuestion:text.length>1200?text.substring(0,1200):text)));}
      else if(action=='download'){final path=p['mediaUrl']?.toString();final bytes=path==null?Uint8List.fromList(utf8.encode(p['caption']?.toString()??'')):await widget.api.socialMedia(path);await FilePicker.platform.saveFile(dialogTitle:'Save post attachment',fileName:p['mediaName']?.toString()??'myaaptha-post-$id.txt',bytes:bytes);}
    }catch(e){if(mounted)setState(()=>error='$e');}
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
              trailing: IconButton(tooltip:'Post options',icon:const Icon(Icons.more_horiz),onPressed:()=>postOptions(p))),
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
                        focusNode:commentFocus.putIfAbsent(id,()=>FocusNode()),
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
  final MyAapthaApi api;
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
            SliverToBoxAdapter(child: ListTile(leading: const Icon(Icons.contacts_outlined),title: const Text('Private contact lists'),subtitle: const Text('View imported contacts by circle. These contacts are separate from messaging members.'),onTap: ()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AddressBookScreen(api:widget.api))))),
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
                                            fontWeight: FontWeight.w500))),
                                title: Text(circle.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
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
  final MyAapthaApi api;
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final query = TextEditingController();
  List<PeopleMatch> results = [];
  PeopleDiscovery? discovery;
  final added = <int>{};
  @override
  void dispose() { query.dispose(); super.dispose(); }
  bool loading = false;
  String? error;
  Future<void> search() async {
    if (query.text.trim().length < 2 || loading) return;
    setState(() => loading = true);
    try {
      final response = await widget.api.discoverPeople(query.text.trim());
      if (!mounted) return;
      discovery = response;
      results = response.people;
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
                subtitle: 'Find people and explore shared connections and interests.')),
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchBar(
                    controller: query,
                    hintText: 'Search MyAaptha…',
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
        if (discovery != null) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Text('${discovery!.rankingMode == 'AI_ASSISTED' ? 'AI assisted search. ' : ''}${discovery!.explanation}${discovery!.limited ? ' Refine your search to see more matches.' : ''}'))),
        if (error != null)
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(error!,
                      style: const TextStyle(
                          color: Color(0xFFB4233C),
                          fontWeight: FontWeight.w500))))
        else
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final match = results[i];
                    final person = match.person;
                    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [_Avatar(person), const SizedBox(width: 12), Expanded(child: Text(person.displayName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)))]),
                      if (person.location != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(person.location!)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 6, runSpacing: 6, children: match.reasons.map((reason) => Chip(label: Text(reason))).toList()),
                      if (match.mutualConnections.isNotEmpty) ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('${match.mutualConnections.length} shared connections'), children: match.mutualConnections.map((connection) => ListTile(title: Text(connection.displayName), subtitle: Text('Your ${connection.yourRelationship} / their ${connection.sharedRelationship}'))).toList()),
                      if (match.sharedInterests.isNotEmpty) Text('Shared interests: ${match.sharedInterests.join(', ')}'),
                      if (match.sharedEmployer != null) Text('Shared workplace: ${match.sharedEmployer}'),
                      const SizedBox(height: 12),
                      FilledButton.tonal(onPressed: match.alreadyConnected || added.contains(person.id) ? null : () => add(person), child: Text(match.alreadyConnected || added.contains(person.id) ? 'In your network' : 'Add connection')),
                    ])));

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
                          fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField(
                      initialValue: relation,
                      decoration:
                          const InputDecoration(labelText: 'Relationship'),
                      items: [
                        'Friend',
                        'Mother',
                        'Father',
                        'Cousin',
                        'Other',
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
          setState(() => added.add(person.id));
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
      {super.key, required this.api, required this.onDataChanged, this.area});
  final MyAapthaApi api;
  final String? area;
  final VoidCallback onDataChanged;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  UserProfileModel? profile;
  String? error;
  bool saving = false;
  bool mediaBusy = false;
  String? editing;
  final fields = <String, TextEditingController>{};
  final sections = const <String, List<(String, String)>>{
    'Personal details': [('firstName','First name'),('surname','Surname'),('email','Email'),('phoneNumber','Mobile number'),('dateOfBirth','Date of birth'),('gender','Gender'),('location','General location'),('bio','About me')],
    'Address': [('addressLine1','Address line 1'),('addressLine2','Address line 2'),('city','City'),('state','State'),('postalCode','Postal code'),('country','Country')],
    'Communication & social media': [('alternatePhone','Alternate phone'),('website','Website'),('whatsapp','WhatsApp'),('linkedin','LinkedIn'),('facebook','Facebook'),('instagram','Instagram'),('xHandle','X / Twitter handle')],
    'Education': [('highestQualification','Highest qualification'),('institution','School / College / University'),('fieldOfStudy','Field of study'),('graduationYear','Graduation year')],
    'Interests': [('hobbies','Hobbies & interests (separate with commas)')],
    'Employment': [('employmentStatus','Employment status'),('employer','Employer'),('jobTitle','Job title'),('industry','Industry'),('workLocation','Work location')],
  };
  Iterable<(String,String)> get definitions => sections.values.expand((items)=>items);
  void beginEdit(String title) {
    for(final item in definitions) { fields[item.$1]!.text=profile!.value(item.$1); }
    setState(()=>editing=title);
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); for(final controller in fields.values) { controller.dispose(); } super.dispose(); }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Returning from another workspace section refreshes the shared profile.
    // Keep an open editor or upload intact; saves still merge with latest data.
    if(editing==null && !saving && !mediaBusy) load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed && editing==null && !saving && !mediaBusy) load();
  }

  Future<void> load() async {
    try {
      final value = await widget.api.profile();
      for (final item in definitions) {
        fields.putIfAbsent(item.$1,()=>TextEditingController()).text = value.value(item.$1);
      }
      if (mounted) setState(() { profile = value; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: _PageHeader(
                eyebrow: 'MY IDENTITY',
                title: widget.area ?? 'Profile',
                subtitle: 'Personal, contact, education and work details.')),
        if (error != null)
          SliverFillRemaining(child: _ErrorState(error!, retry: load))
        else if (profile == null)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
              sliver: SliverList.list(children: [
                if(widget.area==null) ...[
                Card(child: ListTile(leading: const Icon(Icons.contacts_outlined),title: const Text('My contacts'),subtitle: const Text('Import all contacts privately and organize into circles.'),onTap: ()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AddressBookScreen(api:widget.api))))),
                Card(
                    child: ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.auto_awesome_rounded)),
                        title: const Text('AI Contact Organizer',
                            style: TextStyle(fontWeight: FontWeight.w500)),
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
                            style: TextStyle(fontWeight: FontWeight.w500)),
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
                  child: Container(
                    decoration: BoxDecoration(borderRadius:BorderRadius.circular(16),gradient:const LinearGradient(colors:[Color(0xFFEAF4F5),Color(0xFFF0EBFC)])),
                    padding:const EdgeInsets.all(24),
                    child:Column(children:[
                      CircleAvatar(radius:48,child:ClipOval(child:profile!.value('profilePhoto').isEmpty?const Icon(Icons.person_rounded,size:44):Image.network(widget.api.profilePhotoUrl(profile!.value('profilePhoto')),width:96,height:96,fit:BoxFit.cover,errorBuilder:(_,error,stack)=>const Icon(Icons.person_rounded,size:44)))),
                      const SizedBox(height:16),
                      Text([profile!.value('firstName'),profile!.value('surname')].where((x)=>x.isNotEmpty).join(' ').isEmpty?'Your profile':[profile!.value('firstName'),profile!.value('surname')].where((x)=>x.isNotEmpty).join(' '),style:Theme.of(context).textTheme.headlineSmall,textAlign:TextAlign.center),
                      if(profile!.value('bio').isNotEmpty) Padding(padding:const EdgeInsets.only(top:8),child:Text(profile!.value('bio'),textAlign:TextAlign.center)),
                      if(profile!.value('location').isNotEmpty) Padding(padding:const EdgeInsets.only(top:8),child:Text(profile!.value('location'))),
                    ]),
                  ),
                ),
                ProfileMediaCard(api:widget.api,profile:profile!,enabled:editing==null&&!saving,onBusy:(value)=>setState(()=>mediaBusy=value),onChanged:(value){setState(()=>profile=value);widget.onDataChanged();}),
                ],
                for(final section in sections.entries.where((section)=>widget.area==null||(widget.area=='Career'?['Education','Employment'].contains(section.key):section.key=='Interests'))) Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[Expanded(child:Text(section.key,style:Theme.of(context).textTheme.titleMedium)),if(editing!=section.key) TextButton(onPressed:saving||mediaBusy?null:()=>beginEdit(section.key),child:Text('Edit',semanticsLabel:'Edit ${section.key}'))]),
                  const SizedBox(height:12),
                  if(editing==section.key) ...[
                    for(final item in section.value) Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:fields[item.$1],readOnly:item.$1=='phoneNumber',maxLines:item.$1=='bio'?3:1,keyboardType:item.$1=='email'?TextInputType.emailAddress:item.$1.toLowerCase().contains('phone')?TextInputType.phone:TextInputType.text,decoration:InputDecoration(labelText:item.$2,hintText:item.$1=='dateOfBirth'?'YYYY-MM-DD':null))),
                    Wrap(spacing:8,children:[TextButton(onPressed:saving?null:(){setState(()=>editing=null);load();},child:const Text('Cancel')),FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving…':'Save ${section.key}'))]),
                  ] else for(final item in section.value) Padding(padding:const EdgeInsets.only(bottom:14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.$2,style:Theme.of(context).textTheme.labelMedium?.copyWith(color:const Color(0xFF59697D))),const SizedBox(height:4),Text(profile!.value(item.$1).isEmpty?'Not added yet':profile!.value(item.$1))])),
                ]))),
              ]))
      ]);
  Future<void> save() async {
    setState(() => saving = true);
    try {
      final latest = await widget.api.profile();
      final data = Map<String, dynamic>.from(latest.data);
      for (final item in sections[editing]!) {
        data[item.$1] = fields[item.$1]!.text.trim();
      }
      final updated = await widget.api.saveProfile(data);
      if (!mounted) return;
      setState(() { profile = updated; editing = null; });
      widget.onDataChanged();
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
  final MyAapthaApi api;
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
  final MyAapthaApi api;
  @override
  State<ContactOrganizerScreen> createState() => _ContactOrganizerScreenState();
}

class _ContactOrganizerScreenState extends State<ContactOrganizerScreen> {
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> suggestions = [];
  final TextEditingController emailController = TextEditingController();
  Map<String, dynamic> providers = {};
  bool providersLoading = false, oauthConnecting = false;
  String? providerError;
  int oauthGeneration = 0;

  @override
  void initState() {
    super.initState();
    loadProviders();
  }

  Future<void> loadProviders() async {
    if (providersLoading) return;
    setState(() { providersLoading = true; providerError = null; });
    try {
      final available = await widget.api.addressBookProviders();
      if (mounted) setState(() => providers = available);
    } catch (_) {
      if (mounted) setState(() { providers = {}; providerError = 'Contact providers could not be checked.'; });
    } finally {
      if (mounted) setState(() => providersLoading = false);
    }
  }

  void cancelOAuth() {
    oauthGeneration++;
    setState(() { oauthConnecting = false; loading = false; error = 'Contact connection cancelled. Nothing was saved.'; });
  }

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
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text('Preparing contacts for review...'),
                    if (oauthConnecting) TextButton(onPressed: cancelOAuth, child: const Text('Cancel connection')),
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
                ?.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text(
            'MyAaptha reads your phonebook only after permission. Raw contacts are not retained during analysis. You review every relationship and circle before anything is added.',
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
                      color: Colors.red, fontWeight: FontWeight.w500))),
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
                  onPressed: providers['google'] == true && !providersLoading ? () => connectProvider('google') : null,
                  icon: const Icon(Icons.contact_mail_outlined),
                  label: const Text('Google'))),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: providers['microsoft'] == true && !providersLoading ? () => connectProvider('microsoft') : null,
                  icon: const Icon(Icons.business_outlined),
                  label: const Text('Outlook')))
        ]),
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'MyAaptha opens the provider consent page with read-only contact access. Your email password is never requested or stored.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF59697D)))),
        if (providersLoading) const Text('Checking contact providers...'),
        if (!providersLoading && providerError == null && providers['google'] != true && providers['microsoft'] != true)
          const Text('Email contact providers are not available yet. You can use this device or import a file in My contacts.'),
        if (providerError != null) ...[
          Text(providerError!),
          TextButton(onPressed: loadProviders, child: const Text('Retry providers')),
        ],
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
    if (loading || providersLoading || providers[provider] != true) return;
    final email = emailController.text.trim();
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      setState(() => error = 'Enter a valid Google or Outlook email address.');
      return;
    }
    final generation = ++oauthGeneration;
    bool active() => mounted && generation == oauthGeneration;
    setState(() { loading = true; oauthConnecting = true; error = null; });
    try {
      final started = await widget.api.startContactOAuth(email, provider);
      if (!active()) return;
      if (!await launchUrl(Uri.parse(started['authorizationUrl'].toString()), mode: LaunchMode.externalApplication)) {
        throw const MyAapthaApiException('The provider consent page could not be opened.');
      }
      final result = await waitForContactOAuth(
        () => widget.api.contactOAuthResult(started['resultKey'].toString()), isActive: active);
      if (!active()) return;
      for (final item in result) { item['selected'] = item['phone'] != null || item['email'] != null; }
      setState(() { suggestions = result; if (result.isEmpty) error = 'No contacts were found in this account. Nothing was saved.'; });
    } on ContactOAuthCancelled {
      // Leaving/cancelling invalidates this attempt; a newer attempt owns the UI.
    } catch (exception) {
      if (active()) setState(() => error = exception.toString());
    } finally {
      if (active()) setState(() { loading = false; oauthConnecting = false; });
    }
  }

  Widget reviewView() => Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              Expanded(
                  child: Text(
                      '${suggestions.where((item) => item['selected'] == true).length} of ${suggestions.length} selected',
                      style: const TextStyle(fontWeight: FontWeight.w500))),
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
                      color: Colors.red, fontWeight: FontWeight.w500))),
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
                                            fontWeight: FontWeight.w500)),
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
                                        fontSize: 14,
                                        color: Color(0xFF59697D))),
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
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final contacts = await readPermittedDeviceContacts(isActive: () => mounted);
      if (!mounted) return;
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
      if (payload.isEmpty) {
        setState(() => error = 'No named contacts are available with the current permission. Nothing was uploaded.');
        return;
      }
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
  final MyAapthaApi api;
  final Person person;
  @override
  Widget build(BuildContext context) => ConversationScreen(
      title: person.displayName,
      subtitle: 'Private conversation',
      forwardMessage:(id,targets)=>api.forwardChatMessage('DIRECT',person.id,id,targets),
      forwardTargets:api.forwardTargets,
      setMessageFlags: (id,star,pin)=>api.setMessageFlags(person.id,id,star,pin),
      loadSaved: (kind,before)=>api.savedMessages(person.id,kind,beforeId:before),
      acknowledgeRead: (ids)=>api.acknowledgeMessages(person.id,ids),
      load: () => api.directMessages(person.id),
          loadEarlier: (id) => api.directMessages(person.id, beforeId: id),
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
      deleteForMe: (id) => api.deleteDirectMessageForMe(person.id,id),
      reactMessage: (id, emoji) => api.reactDirectMessage(person.id, id, emoji),
      loadPresence: () => api.directPresence(person.id),
      setTyping: (typing) => api.setDirectTyping(person.id, typing),
      person: person);
}

class CircleChatScreen extends StatefulWidget {
  const CircleChatScreen({super.key, required this.api, required this.circle});
  final MyAapthaApi api;
  final CircleModel circle;
  @override
  State<CircleChatScreen> createState() => _CircleChatScreenState();
}

class _CircleChatScreenState extends State<CircleChatScreen> {
  late CircleModel circle = widget.circle;

  @override
  Widget build(BuildContext context) => ConversationScreen(
          circleConversation:true,
          title: circle.name,
          subtitle: '${circle.members.length} members',
          forwardTargets:widget.api.forwardTargets,
          forwardMessage:(id,targets)=>widget.api.forwardChatMessage('CIRCLE',circle.id,id,targets),
          setMessageFlags:(id,star,pin)=>widget.api.setCircleMessageFlags(circle.id,id,star,pin),
          load: () => widget.api.circleMessages(circle.id),
          loadEarlier: (id) => widget.api.circleMessages(circle.id, beforeId: id),
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
          deleteForMe: (id) => widget.api.deleteCircleMessageForMe(circle.id,id),
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
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500))),
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
                                        fontWeight: FontWeight.w500)),
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
      this.loadEarlier,
      required this.send,
      required this.sendAttachment,
      required this.fetchAttachment,
      this.actions = const [],
      this.allowReplies = false,
      this.circleConversation = false,
      this.searchMessages,
      this.editMessage,
      this.deleteMessage,
      this.deleteForMe,
      this.reactMessage,
      this.loadPresence,
      this.setTyping,
      this.person, this.setMessageFlags, this.loadSaved, this.acknowledgeRead, this.forwardTargets, this.forwardMessage});
  final String title, subtitle;
  final Future<List<ConversationMessage>> Function() load;
  final Future<List<ConversationMessage>> Function(int beforeId)? loadEarlier;
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
  final bool allowReplies, circleConversation;
  final Future<List<ConversationMessage>> Function(String query)?
      searchMessages;
  final Future<void> Function(int id, String value)? editMessage;
  final Future<void> Function(int id)? deleteMessage;
  final Future<void> Function(int id)? deleteForMe;
  final Future<void> Function(int id, String emoji)? reactMessage;
  final Future<Map<String, dynamic>> Function()? loadPresence;
  final Future<void> Function(bool typing)? setTyping;
  final Future<List<ChatTarget>> Function()? forwardTargets;
  final Future<void> Function(int,List<ChatTarget>)? forwardMessage;
  final Future<void> Function(int,bool?,bool?)? setMessageFlags;
  final Future<List<ConversationMessage>> Function(String,int?)? loadSaved;
  final Future<void> Function(List<int>)? acknowledgeRead;
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
  bool loading = false;
  bool hasEarlier = true;
  PlatformFile? selectedFile;
  ConversationMessage? replyingTo;
  double? uploadProgress;
  bool showingSearchResults = false;
  String? presenceText;
  String? savedKind;
  final viewportKey=GlobalKey();
  final messageKeys=<int,GlobalKey>{};
  final acknowledged=<int>{};
  bool receiptBusy=false;
  void scheduleReceipts() => WidgetsBinding.instance.addPostFrameCallback((_)=>acknowledgeVisible());
  Future<void> acknowledgeVisible() async {
    if(!mounted||receiptBusy||widget.acknowledgeRead==null||WidgetsBinding.instance.lifecycleState!=AppLifecycleState.resumed||ModalRoute.of(context)?.isCurrent!=true)return;
    final viewport=viewportKey.currentContext?.findRenderObject();
    if(viewport is! RenderBox || !viewport.hasSize)return;
    final bounds=viewport.localToGlobal(Offset.zero)&viewport.size;
    final ids=<int>[];
    for(final item in messages??<ConversationMessage>[]) {
      if(item.mine||item.readAt!=null||acknowledged.contains(item.id))continue;
      final box=messageKeys[item.id]?.currentContext?.findRenderObject();
      if(box is RenderBox&&box.attached&&box.hasSize&&bounds.overlaps(box.localToGlobal(Offset.zero)&box.size))ids.add(item.id);
    }
    if(ids.isEmpty)return;receiptBusy=true;
    try{final batch=ids.take(100).toList();await widget.acknowledgeRead!(batch);acknowledged.addAll(batch);}catch(_){/* Retry on the next foreground poll. */}finally{receiptBusy=false;}
  }

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
    if (loading || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    loading = true;
    try {
      final value = savedKind==null ? await widget.load() : await widget.loadSaved!(savedKind!,null);
      if (mounted) {
        setState(() {
          final previous = showingSearchResults ? <ConversationMessage>[] : messages ?? <ConversationMessage>[];
          final gap = previous.isNotEmpty && value.length == 50 && value.first.id > previous.last.id;
          final merged = {for (final item in gap ? <ConversationMessage>[] : previous) item.id: item,
                          for (final item in value) item.id: item};
          messages = merged.values.toList()..sort((a,b) => a.id.compareTo(b.id));
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally { loading = false; if(mounted)scheduleReceipts(); }
  }

  Future<void> loadEarlier() async {
    if (loading || widget.loadEarlier == null || messages == null || messages!.isEmpty) { return; }
    setState(() => loading = true);
    try {
      final older = savedKind==null ? await widget.loadEarlier!(messages!.first.id) : await widget.loadSaved!(savedKind!,messages!.first.id);
      if (mounted) { setState(() {
        final merged = {for(final item in older) item.id:item, for(final item in messages!) item.id:item};
        messages = merged.values.toList()..sort((a,b)=>a.id.compareTo(b.id));
        hasEarlier = older.length == 50;
      }); }
    } catch(e) { if(mounted) setState(()=>error=e.toString()); }
    finally { if(mounted) setState(()=>loading=false); }
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
      messages = null;
      hasEarlier = true;
      await load();
      return;
    }
    try {
      final result = await widget.searchMessages!(query);
      if (mounted) {
        setState(() {
          messages = result;
          showingSearchResults = true; savedKind=null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> messageAction(ConversationMessage item, String action) async {
    try {
      if(action=='star'||action=='pin') {
        await widget.setMessageFlags!(item.id,action=='star'?!item.starred:null,action=='pin'?!item.pinned:null);
        if(mounted && savedKind!=null)setState(()=>messages=null);
        await load();return;
      }
      if(action=='forward') {
        final targets=await widget.forwardTargets!();
        if(!mounted)return;
        final selected=<String,ChatTarget>{};String query='';
        final chosen=await showDialog<List<ChatTarget>>(context:context,builder:(context)=>StatefulBuilder(builder:(context,update)=>AlertDialog(
          title:const Text('Forward message'),
          content:SizedBox(width:360,height:360,child:Column(children:[
            TextField(decoration:const InputDecoration(labelText:'Find people or circles',prefixIcon:Icon(Icons.search)),onChanged:(value)=>update(()=>query=value)),
            Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text('${selected.length} / 10 selected')),
            if(targets.isEmpty)const Text('No eligible people or circles yet.'),
            Expanded(child:ListView(children:[for(final target in targets.where((t)=>t.name.toLowerCase().contains(query.toLowerCase())))CheckboxListTile(
              title:Text(target.name),subtitle:Text(target.type=='CIRCLE'?'Circle':'Person'),value:selected.containsKey(target.key),
              onChanged:!selected.containsKey(target.key)&&selected.length>=10?null:(checked)=>update((){if(checked==true){selected[target.key]=target;}else{selected.remove(target.key);}}))]))])),
          actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:selected.isEmpty?null:()=>Navigator.pop(context,selected.values.toList()),child:const Text('Send forward'))])));
        if(chosen==null)return;
        await widget.forwardMessage!(item.id,chosen);
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Message forwarded.')));
        await load();return;
      }
      if(action=='react'){
        final emoji=await showModalBottomSheet<String>(context:context,builder:(sheet)=>SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:Wrap(alignment:WrapAlignment.center,spacing:8,children:[for(final emoji in ['\u{1f44d}','\u2764\ufe0f','\u{1f602}','\u{1f62e}','\u{1f622}','\u{1f64f}'])IconButton(tooltip:'React $emoji',onPressed:()=>Navigator.pop(sheet,emoji),icon:Text(emoji,style:const TextStyle(fontSize:24)))]))));
        if(emoji!=null){await widget.reactMessage!(item.id,item.myReaction==emoji?'':emoji);await load();}return;
      }
      if(action=='copy'){await Clipboard.setData(ClipboardData(text:item.message));return;}
      if(action=='info'){
        await showDialog<void>(context:context,builder:(context)=>AlertDialog(title:const Text('Message info'),content:Text(widget.circleConversation?'Sent: ${item.createdAt.toLocal()}\nRead by ${item.readCount} members':'Sent: ${item.createdAt.toLocal()}\nReceived by recipient app: ${item.deliveredAt?.toLocal()??"Not confirmed"}\nRead: ${item.readAt?.toLocal()??"Not confirmed or receipts disabled"}'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))]));return;
      }
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
        final scope=await showModalBottomSheet<String>(context:context,builder:(sheetContext)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
          if(widget.deleteForMe!=null) ListTile(leading:const Icon(Icons.person_outline),title:const Text('Delete for me'),onTap:()=>Navigator.pop(sheetContext,'me')),
          if(item.canDeleteForAll && DateTime.now().isBefore(item.createdAt.add(const Duration(hours:24)))) ListTile(leading:const Icon(Icons.delete_outline),title:const Text('Delete for all'),onTap:()=>Navigator.pop(sheetContext,'all')),
        ])));
        if(scope==null||!mounted)return;
        if(scope=='me'){await widget.deleteForMe!(item.id);if(mounted)setState(()=>messages?.removeWhere((message)=>message.id==item.id));}else{
          final confirmed=await _confirmDestructiveAction(context,title:'Delete for all?',message:'The message and attachment will be replaced with a deleted-message notice for all participants.',confirmLabel:'Delete for all');
          if(!confirmed)return;
          await widget.deleteMessage!(item.id);
          if(mounted)setState(()=>messages=null);
        }
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
          throw const MyAapthaApiException('Could not read the selected file.');
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
        'docx',
        'xlsx',
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
            Expanded(child:Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title,maxLines:1,overflow:TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              Text(presenceText ?? widget.subtitle,maxLines:1,overflow:TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF59697D)))
            ]))
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
        if(widget.loadSaved!=null) Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:DropdownButtonFormField<String>(initialValue:savedKind??'all',decoration:const InputDecoration(labelText:'Show messages'),items:const [DropdownMenuItem(value:'all',child:Text('All')),DropdownMenuItem(value:'starred',child:Text('Starred')),DropdownMenuItem(value:'pinned',child:Text('Pinned for me'))],onChanged:(value){setState((){savedKind=value=='all'?null:value;messages=null;showingSearchResults=false;hasEarlier=true;});load();})),

        if (!showingSearchResults && hasEarlier && (messages?.length ?? 0) >= 50 && widget.loadEarlier != null)
          TextButton(onPressed: loading ? null : loadEarlier, child: const Text('Load earlier messages')),
        if (error != null)
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFFF4F7FA),
              child: Text(error!,
                  style: const TextStyle(
                      color: Color(0xFFB4233C), fontWeight: FontWeight.w500))),
        Expanded(
            child: NotificationListener<ScrollNotification>(onNotification:(_){scheduleReceipts();return false;},child:SizedBox(key:viewportKey, child: messages == null
                ? const Center(child: CircularProgressIndicator())
                : messages!.every((message)=>message.hiddenForMe)
                    ? const Center(
                        child: Text('No messages yet. Start the conversation.'))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(14),
                        itemCount: messages!.length,
                        itemBuilder: (context, index) {
                          final item = messages![messages!.length - 1 - index];
                          if(item.hiddenForMe)return const SizedBox.shrink();
                          final parent = _messageById(item.parentMessageId);
                          return Align(
                              key:messageKeys.putIfAbsent(item.id,()=>GlobalKey()),
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
                                          ? const Color(0xFFF4F7FA)
                                          : Colors.white,
                                      border: Border.all(
                                          color: item.mine
                                              ? const Color(0xFFEAF4F5)
                                              : const Color(0xFFD9E2EA)),
                                      borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(
                                              item.mine ? 16 : 4),
                                          bottomRight: Radius.circular(
                                              item.mine ? 4 : 16))),
                                  child:
                                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(item.mine ? 'You' : item.authorName,
                                          style: const TextStyle(
                                              color: AppTheme.primary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500)),
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
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500)),
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
                                                        fontSize: 14))
                                              ]))
                                    ],
                                    if (item.deleted)
                                      const Text('This message was deleted',
                                          style: TextStyle(
                                              color: Color(0xFF59697D),
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
                                                  color: Color(0xFF59697D),
                                                  fontSize: 14)),
                                          if (item.editedAt != null)
                                            const Text(' · edited',
                                                style: TextStyle(
                                                    color: Color(0xFF59697D),
                                                    fontSize: 14)),
                                          if (item.mine && widget.acknowledgeRead != null)
                                            Semantics(label:item.readAt!=null?'Read':item.deliveredAt!=null?'Delivered':'Sent',child:Icon(item.readAt!=null||item.deliveredAt!=null?Icons.done_all:Icons.done,size:15,color:item.readAt!=null?AppTheme.primary:Colors.grey)),
                                          if(item.forwarded&&!item.deleted) const Text(' Forwarded',style:TextStyle(fontSize: 14)),
                                          if(item.starred) const Icon(Icons.star,size:13),
                                          if(item.pinned) const Icon(Icons.push_pin,size:13),
                                          if (item.mine && item.readCount > 0)
                                            Text('  ✓✓ ${item.readCount}',
                                                style: const TextStyle(
                                                    color: AppTheme.primary,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w500)),
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
                                            PopupMenuButton<String>(
                                                tooltip: 'Message actions',
                                                padding: EdgeInsets.zero,
                                                onSelected: (value) =>
                                                    messageAction(item, value),
                                                itemBuilder: (_) => [
                                                      if(widget.setMessageFlags!=null && !item.deleted) ...[
                                                        PopupMenuItem(value:'star',child:Text(item.starred?'Unstar':'Star')),
                                                        PopupMenuItem(value:'pin',child:Text(item.pinned?'Unpin for me':'Pin for me')),
                                                      ],
                                                      if(widget.forwardMessage!=null&&!item.deleted) const PopupMenuItem(value:'forward',child:Text('Forward')),
                                                      const PopupMenuItem(value:'info',child:Text('Info')),
                                                      if(!item.deleted && item.message.isNotEmpty) const PopupMenuItem(value:'copy',child:Text('Copy text')),

                                                      if(widget.allowReplies&&!item.deleted)const PopupMenuItem(
                                                          value: 'reply',
                                                          child: Text('Reply')),
                                                      if (item.mine && widget.editMessage!=null &&
                                                          !item.deleted)
                                                        const PopupMenuItem(
                                                            value: 'edit',
                                                            child:
                                                                Text('Edit')),
                                                      if (widget.deleteForMe != null)
                                                        const PopupMenuItem(
                                                            value: 'delete',
                                                            child:
                                                                Text('Delete')),
                                                      if(!item.deleted&&widget.reactMessage!=null)const PopupMenuItem(value:'react',child:Text('React')),

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
                        })))),
        if (replyingTo != null)
          Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
              color: const Color(0xFFF4F7FA),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      Text(
                          replyingTo!.message.isNotEmpty
                              ? replyingTo!.message
                              : replyingTo!.attachmentName ?? 'Attachment',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14))
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
                    border: Border(top: BorderSide(color: Color(0xFFEAF4F5)))),
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
                              fontSize: 14, fontWeight: FontWeight.w500),
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
      if(message.hiddenForMe)continue;
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
              border: Border.all(color: const Color(0xFFEAF4F5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF4F7FA),
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
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_label(type)} · ${_size(widget.message.attachmentSize)}',
                      style: const TextStyle(
                        color: Color(0xFF59697D),
                        fontSize: 14,
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
        style: TextStyle(color: Color(0xFFB4233C), fontWeight: FontWeight.w500),
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

/// Section tabs retain the existing screens and their local state after visiting.
class WorkspaceHub extends StatefulWidget {
  const WorkspaceHub({super.key,required this.title,required this.labels,required this.pages});
  final String title;
  final List<String> labels;
  final List<Widget> pages;
  @override State<WorkspaceHub> createState()=>_WorkspaceHubState();
}
class _WorkspaceHubState extends State<WorkspaceHub> {
  int selected=0;
  final visited=<int>{0};
  @override Widget build(BuildContext context)=>Column(children:[
    Padding(padding:const EdgeInsets.fromLTRB(16,8,16,0),child:Align(alignment:Alignment.centerLeft,child:Text(widget.title,style:Theme.of(context).textTheme.titleLarge))),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[for(int i=0;i<widget.labels.length;i++)Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(widget.labels[i]),selected:selected==i,onSelected:(_)=>setState((){selected=i;visited.add(i);}))) ]))),
    Expanded(child:IndexedStack(index:selected,children:[for(int i=0;i<widget.pages.length;i++)visited.contains(i)?widget.pages[i]:const SizedBox.shrink()])),
  ]);
}

class MenuComparisonScreen extends StatelessWidget {
  const MenuComparisonScreen({super.key,required this.onOpen});
  final ValueChanged<String> onOpen;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Menu comparison')),body:ListView(padding:const EdgeInsets.all(16),children:[
    Text('Old menu to new home',style:Theme.of(context).textTheme.headlineSmall),
    const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('All existing features remain accessible. Review each move and open its destination.')),
    Wrap(spacing:6,children:[for(final label in workspacePrimaryLabels)Chip(label:Text(label))]),
    for(final move in workspaceMenuMoves)Card(child:ListTile(isThreeLine:true,title:Text(move.old),subtitle:Text('New location: ${move.destination}'),trailing:const Icon(Icons.open_in_new),onTap:()=>onOpen(move.path))),
    const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Career uses your education and employment details. Interests uses your saved hobbies. Online Feed retains stories, sharing audiences and saved posts. Messages retains calls, group conversations, search, unread and archive controls. Previous mobile shortcuts: Notifications is the top bell; Search is available from the top search bar and Messages > Find people; More / All tools is now Account & tools. Sign out remains in the drawer and account tools. This review view can be removed later.'))),
  ]));
}

void openMenuComparison(BuildContext context,MyAapthaApi api,AuthTokenBundle session,VoidCallback signOut){
  Navigator.push(context,MaterialPageRoute(builder:(reviewContext)=>MenuComparisonScreen(onOpen:(path){
    final page=switch(path){
      '/dashboard'=>MobileDashboard(api:api),
      '/relationship-tree'=>NetworkHome(api:api),
      '/feed'=>SocialFeedScreen(api:api),
      '/following'=>FollowConnectionsScreen(api:api),
      '/messages'=>MessagesScreen(api:api),
      '/circles'=>CirclesScreen(api:api),
      '/contacts'=>AddressBookScreen(api:api),
      '/timeline'=>TimelineScreen(api:api),
      '/finance'=>FinanceScreen(api:api),
      '/health'=>HealthRecordsScreen(api:api),
      '/trust'=>TrustCenterScreen(api:api),
      '/profile'=>ProfileScreen(api:api,onDataChanged:(){}),
      '/settings'=>ApplicationSettingsScreen(api:api),
      '/session'=>SessionScreen(session:session,onSignOut:signOut),
      '/ai-activity'=>AiControlScreen(api:api),
      '/help'=>HelpChatScreen(api:api),
      '/reports'=>ReportsScreen(api:api),
      '/moderation'=>ModerationScreen(api:api),
      _=>const Center(child:Padding(padding:EdgeInsets.all(24),child:Text('Security & errors remains available to administrators in the web application.'))),
    };
    Navigator.push(reviewContext,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:Text(workspaceMenuMoves.firstWhere((move)=>move.path==path).old)),body:page)));
  })));
}
