import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/core/platform/attachment_opener.dart';
import 'package:myaaptha_mobile/core/widgets/info_help.dart';

class EmergencyDocumentsScreen extends StatefulWidget {
  const EmergencyDocumentsScreen({super.key,required this.api,required this.requestId,this.opener});
  final MyAapthaApi api;
  final int requestId;
  final Future<bool> Function(Uint8List,String,String)? opener;
  @override State<EmergencyDocumentsScreen> createState()=>_EmergencyDocumentsScreenState();
}
class _EmergencyDocumentsScreenState extends State<EmergencyDocumentsScreen> with WidgetsBindingObserver {
  List<Map<String,dynamic>> documents=[];
  bool loading=true,opening=false;
  String? error;
  int version=0;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed&&!opening)load();}
  Future<void> load() async {
    final current=++version;setState((){loading=true;error=null;});
    try{final rows=await widget.api.emergencyDocuments(widget.requestId);if(mounted&&current==version)setState(()=>documents=rows);}
    catch(e){if(mounted&&current==version)setState((){documents=[];error=e.toString();});}
    finally{if(mounted&&current==version)setState(()=>loading=false);}
  }
  Future<void> open(Map<String,dynamic> document) async {
    if(opening)return;
    setState(()=>opening=true);
    try{
      final id=(document['id'] as num).toInt();
      // Construct a same-API path rather than following arbitrary document URLs.
      // The server rechecks requester, current Star status and grant expiry.
      final bytes=await widget.api.attachment('/api/trust/emergencies/${widget.requestId}/documents/$id/media');
      final opened=await (widget.opener??openAttachmentBytes)(bytes,document['mediaType']?.toString()??'application/octet-stream',document['mediaName']?.toString()??'emergency-document');
      if(!opened)throw StateError('No application could open this document.');
    }catch(e){if(mounted){version++;setState((){documents=[];error=e.toString();loading=false;});}}
    finally{if(mounted)setState(()=>opening=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Emergency documents'),actions:const [InfoHelp(title:'Emergency documents',message:'Only the approved requester can open these documents during the grant window. Each open is checked by the server. Opening in another application creates a local copy; server expiry cannot recall copies already opened.')]),body:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.all(16),children:[
    if(error!=null)...[Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),TextButton(onPressed:load,child:const Text('Check access again'))]
    else if(documents.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('No eligible documents are available.')),
    if(opening)const LinearProgressIndicator(semanticsLabel:'Opening authorized document'),
    for(final document in documents)Card(child:ListTile(leading:const Icon(Icons.description_outlined),title:Text(document['mediaName']?.toString()??'Document'),subtitle:Text(document['caption']?.toString()??''),trailing:const Icon(Icons.open_in_new),enabled:!opening,onTap:()=>open(document))),
  ])));
}
