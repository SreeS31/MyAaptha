import 'dart:math';
import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/core/widgets/info_help.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key,required this.api});
  final MyAapthaApi api;
  @override State<TimelineScreen> createState()=>_TimelineScreenState();
}
class _TimelineScreenState extends State<TimelineScreen> with WidgetsBindingObserver {
  List<Map<String,dynamic>> events=[];
  final savedKeys=<String>{},sourceKeys=<String>{};
  bool loading=true,compact=false,editing=false;
  String? error;
  static const kinds=['Birth','Family','Remembrance','Education','Marriage','Employment','Other'];
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed&&!editing)load();}
  Future<void> load() async {
    try {
      final profile=await widget.api.profile();
      final relations=await widget.api.timelineRelationships();
      final saved=await widget.api.timelineEvents();
      final combined=<String,Map<String,dynamic>>{};
      void add(String key,String date,String kind,String title,String detail){if(date.isNotEmpty)combined[key]={'eventKey':key,'date':date,'kind':kind,'title':title,'detail':detail};}
      add('profile-birth',profile.value('dateOfBirth'),'Birth','Born',profile.value('location'));
      final graduation=profile.value('graduationYear');
      if(graduation.isNotEmpty)add('profile-education','$graduation-12-31','Education',profile.value('highestQualification').isEmpty?'Graduated':profile.value('highestQualification'),[profile.value('institution'),profile.value('fieldOfStudy')].where((s)=>s.isNotEmpty).join(' · '));
      for(final relation in relations){
        final type=(relation['type']??'').toString().toLowerCase();
        final name=((relation['person'] as Map?)?['displayName']??'Family member').toString();
        final id=relation['id'];
        if(['wife','husband'].contains(type))add('relation-$id-marriage',(relation['milestoneDate']??'').toString(),'Marriage','Married $name','Marriage with $name');
        if(['son','daughter','grandson','granddaughter'].contains(type))add('relation-$id-birth',(relation['dateOfBirth']??'').toString(),'Family','$name was born','My $type');
        add('relation-$id-death',(relation['dateOfDeath']??'').toString(),'Remembrance','Remembering $name','My $type');
      }
      final derived=combined.keys.toSet();
      for(final event in saved){combined[event['eventKey'] as String]=event;}
      final sorted=combined.values.toList()..sort((a,b){final date=(b['date'] as String).compareTo(a['date'] as String);return date!=0?date:(a['eventKey'] as String).compareTo(b['eventKey'] as String);});
      if(mounted)setState((){events=sorted;sourceKeys..clear()..addAll(derived);savedKeys..clear()..addAll(saved.map((event)=>event['eventKey'] as String));loading=false;error=null;});
    } catch(e){if(mounted)setState((){loading=false;error=e.toString();});}
  }
  Color color(String kind)=>switch(kind){'Birth'||'Family'=>const Color(0xFF2563A6),'Remembrance'=>const Color(0xFFB4233C),'Education'=>const Color(0xFF7250AA),'Marriage'=>const Color(0xFFB23C79),'Employment'=>const Color(0xFF947015),_=>const Color(0xFF256F7B)};
  Future<void> remove(Map<String,dynamic> event) async {
    if(editing)return;
    editing=true;
    final reset=sourceKeys.contains(event['eventKey']);
    final confirmed=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
      title:Text(reset?'Reset to source?':'Delete event?'),
      content:Text(reset?'Remove your timeline edits and show the original profile or relationship milestone?':'Delete this saved timeline event?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(reset?'Reset to source':'Delete event'))]));
    try {if(confirmed==true){await widget.api.deleteTimelineEvent(event['eventKey'] as String);if(mounted)await load();}}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not remove event: $e')));}
    finally {editing=false;}
  }
  Future<void> edit([Map<String,dynamic>? event]) async {
    if(editing)return;
    final title=TextEditingController(text:event?['title'] as String? ?? '');
    final detail=TextEditingController(text:event?['detail'] as String? ?? '');
    final date=TextEditingController(text:event?['date'] as String? ?? DateTime.now().toIso8601String().split('T').first);
    final key=event?['eventKey'] as String? ?? 'custom-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1<<32)}';
    String kind=event?['kind'] as String? ?? 'Other';
    bool saving=false;String? failure;
    final form=GlobalKey<FormState>();
    editing=true;
    await showDialog<void>(context:context,barrierDismissible:false,builder:(context)=>StatefulBuilder(builder:(context,update)=>PopScope(canPop:!saving,child:AlertDialog(
      title:InfoHelpLabel(title:event==null?'Add event':'Edit event',message:'Saved to your timeline. Profile and relationship details remain separate.'),
      content:SingleChildScrollView(child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(initialValue:kind,decoration:const InputDecoration(labelText:'Event type'),items:kinds.map((k)=>DropdownMenuItem(value:k,child:Text(k))).toList(),onChanged:saving?null:(value)=>kind=value!),
        const SizedBox(height:12),
        TextFormField(controller:date,enabled:!saving,decoration:const InputDecoration(labelText:'Date',hintText:'YYYY-MM-DD'),validator:(value)=>value==null||!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)||DateTime.tryParse(value)==null?'Use YYYY-MM-DD':null),
        const SizedBox(height:12),
        TextFormField(controller:title,enabled:!saving,maxLength:200,decoration:const InputDecoration(labelText:'Title'),validator:(value)=>value==null||value.trim().isEmpty?'Enter an event title':null),
        TextFormField(controller:detail,enabled:!saving,maxLength:2000,maxLines:3,decoration:const InputDecoration(labelText:'Details')),
        if(failure!=null)Text(failure!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      ]))),
      actions:[TextButton(onPressed:saving?null:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:saving?null:() async {
        if(!form.currentState!.validate())return;
        update((){saving=true;failure=null;});
        try {await widget.api.saveTimelineEvent({'eventKey':key,'date':date.text,'kind':kind,'title':title.text.trim(),'detail':detail.text.trim()});if(context.mounted)Navigator.pop(context);}
        catch(e){if(context.mounted)update((){saving=false;failure=e.toString();});}
      },child:Text(saving?'Saving…':'Save event'))],
    ))));
    editing=false;
    // Dialog fields finish their closing transition before controllers are disposed.
    await Future<void>.delayed(const Duration(milliseconds:300));
    title.dispose();detail.dispose();date.dispose();
    if(mounted)await load();
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Life timeline'),actions:const [InfoHelp(title:'Life timeline',message:'Latest milestones appear first. Add events or edit a card. Compact view reduces spacing. Changes are shared with the web timeline.')]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!),TextButton(onPressed:load,child:const Text('Try again'))])):RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[
      Wrap(spacing:12,runSpacing:12,alignment:WrapAlignment.spaceBetween,children:[SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('Wave')),ButtonSegment(value:true,label:Text('Compact'))],selected:{compact},onSelectionChanged:(value)=>setState(()=>compact=value.first)),FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('Add event'))]),
      const SizedBox(height:16),
      if(events.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(24),child:Text('No milestones yet. Add your first event.'))),
      for(final event in events) Padding(padding:EdgeInsets.only(bottom:compact?10:22),child:Stack(children:[Positioned.fill(child:IgnorePointer(child:CustomPaint(painter:_TimelineWavePainter(compact)))),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Padding(padding:const EdgeInsets.only(top:16,right:12),child:CircleAvatar(radius:compact?16:22,backgroundColor:color(event['kind'] as String),child:const Icon(Icons.flag_outlined,color:Colors.white,size:20))),
        Expanded(child:Container(padding:EdgeInsets.all(compact?14:20),decoration:BoxDecoration(color:color(event['kind'] as String).withValues(alpha:.04),border:Border.all(color:color(event['kind'] as String),width:1.5),borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Align(alignment:Alignment.topRight,child:Text(event['kind'] as String,style:TextStyle(color:color(event['kind'] as String),fontSize:12,fontWeight:FontWeight.w600))),
          Text(event['date'] as String,style:TextStyle(color:color(event['kind'] as String),fontSize:13)),
          const SizedBox(height:6),Text(event['title'] as String,style:Theme.of(context).textTheme.titleMedium),
          if((event['detail'] as String).isNotEmpty)Text(event['detail'] as String),
          Wrap(spacing:8,children:[TextButton(onPressed:()=>edit(event),child:const Text('Edit event')),
            if(savedKeys.contains(event['eventKey']))TextButton(onPressed:()=>remove(event),child:Text(sourceKeys.contains(event['eventKey'])?'Reset to source':'Delete event'))]),
        ]))),
      ])])),
    ])),
  );
}

class _TimelineWavePainter extends CustomPainter {
 const _TimelineWavePainter(this.compact);
 final bool compact;
 @override void paint(Canvas canvas,Size size){
  final x=compact?16.0:22.0;
  final path=Path()..moveTo(x,0)..cubicTo(x-12,size.height*.2,x+12,size.height*.8,x,size.height);
  canvas.drawPath(path,Paint()..color=const Color(0xFFB5CCD3)..strokeWidth=2..style=PaintingStyle.stroke);
 }
 @override bool shouldRepaint(_TimelineWavePainter old)=>old.compact!=compact;
}
