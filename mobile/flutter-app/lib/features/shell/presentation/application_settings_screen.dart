import 'package:myaaptha_mobile/core/widgets/info_help.dart';
import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'upload_settings_screen.dart';

class ApplicationSettingsScreen extends StatefulWidget {
  const ApplicationSettingsScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<ApplicationSettingsScreen> createState() => _ApplicationSettingsScreenState();
}

class _ApplicationSettingsScreenState extends State<ApplicationSettingsScreen> {
  Map<String, dynamic>? values, notifications;
  bool saving = false;
  String? error, status;
  final zone = TextEditingController();
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { zone.dispose(); super.dispose(); }
  Future<void> load() async {
    try {
      final result = await Future.wait([widget.api.applicationSettings(), widget.api.notificationPreferences()]);
      if (!mounted) return;
      setState(() { values=result[0]; notifications=result[1]; zone.text=values!['timeZone'] as String; error=null; });
    } catch(e) { if(mounted) setState(()=>error=e.toString()); }
  }
  Future<void> save() async {
    if(values==null||notifications==null)return;
    setState(() {saving=true;error=null;status=null;});
    try {
      values!['timeZone']=zone.text.trim();
      final saved=await widget.api.updateApplicationSettings(values!);
      await widget.api.updateNotificationPreferences(notifications!);
      if(mounted)setState(() {values=saved;status='Saved. These preferences follow your account on web and mobile.';});
    } catch(e) {if(mounted)setState(()=>error='Some settings may not have saved. Review and save again. $e');}
    finally {if(mounted)setState(()=>saving=false);}
  }
  Widget option(String key,String title,String detail) => SwitchListTile.adaptive(
    title:InfoHelpLabel(title:title,message:detail),value:values![key]==true,
    onChanged:saving?null:(value)=>setState(() {values![key]=value;status='Unsaved changes';}));
  Widget section(String title,List<Widget> children) => Card(
    elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),side:BorderSide(color:Theme.of(context).colorScheme.outlineVariant)),
    child:Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Text(title,style:Theme.of(context).textTheme.titleLarge)),...children])));
  Future<void> chooseTime(String key) async {
    final parts=(values![key] as String).split(':');
    final chosen=await showTimePicker(context:context,initialTime:TimeOfDay(hour:int.parse(parts[0]),minute:int.parse(parts[1])));
    if(chosen!=null&&mounted)setState(() {values![key]='${chosen.hour.toString().padLeft(2,'0')}:${chosen.minute.toString().padLeft(2,'0')}';status='Unsaved changes';});
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:const Text('Your settings')),
    body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:850),child:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,32),children:[
      Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(22)),child:InfoHelpLabel(title:'Personal settings',message:'Choose how you connect, what reaches you, and how your workspace feels.',style:Theme.of(context).textTheme.headlineSmall)),
      if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      if(values==null||notifications==null)...[const Padding(padding:EdgeInsets.all(30),child:Center(child:CircularProgressIndicator())),if(error!=null)TextButton(onPressed:load,child:const Text('Try again'))]
      else ...[
        section('Discovery & privacy',[
          option('discoverable','Let people find my profile','Appear in searches by name or location. Existing contacts keep their saved connection.'),
          option('shareConnections','Show shared connections','Only explicitly public links, with everyone’s sharing permission, appear in connection suggestions.'),
          option('shareInterests','Share interests & workplace','Use your profile hobbies and employer to find common ground.'),
          option('intelligentSearch','Intelligent search ordering','Prioritize shared information. AI name ranking follows your AI permissions.'),
        ]),
        section('Notifications',[
          ExpansionTile(title:const Text('Activity & delivery channels'),children:[
            for(final item in const {'messagesEnabled':'Private messages','circlesEnabled':'Circle activity','relationshipsEnabled':'Relationships','callsEnabled':'Calls','invitationsEnabled':'Invitations','socialEnabled':'Likes and comments','pushEnabled':'Push notifications','emailEnabled':'Email','smsEnabled':'SMS'}.entries)
              SwitchListTile.adaptive(title:Text(item.value),value:notifications![item.key]==true,onChanged:saving?null:(v)=>setState(() {notifications![item.key]=v;status='Unsaved changes';})),
          ]),
          option('notificationPreviews','Show notification previews','Include names and update details outside the app. Turn off for more privacy.'),
          option('quietHoursEnabled','Quiet hours','Delay external notifications. Your in-app inbox stays available.'),
          Padding(padding:const EdgeInsets.all(16),child:Wrap(spacing:12,runSpacing:10,children:[
            OutlinedButton(onPressed:saving||values!['quietHoursEnabled']!=true?null:()=>chooseTime('quietStart'),child:Text('From ${values!['quietStart']}')),
            OutlinedButton(onPressed:saving||values!['quietHoursEnabled']!=true?null:()=>chooseTime('quietEnd'),child:Text('Until ${values!['quietEnd']}')),
          ])),
          Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(controller:zone,maxLength:80,enabled:!saving,decoration:const InputDecoration(labelText:'Time zone',helperText:'For example: Asia/Kolkata or Europe/London'),onChanged:(_)=>setState(()=>status='Unsaved changes'))),
          const Padding(padding:EdgeInsets.symmetric(horizontal:16),child:InfoHelpLabel(title:'Notification delivery',message:'Delivery also depends on device permissions and enabled delivery channels.')),
        ]),
        section('Layout & accessibility',[
          option('compactLayout','Compact spacing','Fit more into your workspace.'),
          option('reducedMotion','Reduce motion','Minimize animations and transitions.'),
        ]),
        section('Storage & uploads',[
          ListTile(title:const Text('Storage usage & upload limits'),subtitle:const Text('View storage usage, upload limits and expiry choices.'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>UploadSettingsScreen(api:widget.api)))),
        ]),
        if(status!=null)Padding(padding:const EdgeInsets.all(12),child:Semantics(liveRegion:true,child:Text(status!))),
        FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.check_rounded),label:Text(saving?'Saving…':'Save settings')),
      ]
    ]))),
  );
}
