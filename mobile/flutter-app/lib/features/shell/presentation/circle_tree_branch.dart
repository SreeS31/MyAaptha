import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class CircleTreeBranch extends StatefulWidget {
  const CircleTreeBranch({super.key,required this.api,required this.circle,required this.privateCount,required this.unread,required this.onMessages});
  final MyAapthaApi api;
  final CircleModel circle;
  final int privateCount,unread;
  final VoidCallback onMessages;
  @override
  State<CircleTreeBranch> createState()=>_CircleTreeBranchState();
}

class _CircleTreeBranchState extends State<CircleTreeBranch> {
  final List<Map<String,dynamic>> contacts=[];
  bool busy=false,loaded=false;
  int? cursor;
  String? error;
  Future<void> loadContacts() async {
    if(busy)return;
    setState((){busy=true;error=null;});
    try {
      final page=await widget.api.addressBook(circleId:widget.circle.id,afterId:cursor??0);
      if(!mounted)return;
      setState((){contacts.addAll((page['items'] as List).map((row)=>Map<String,dynamic>.from(row as Map)));cursor=(page['nextCursor'] as num?)?.toInt();loaded=true;});
    } catch(e){if(mounted)setState(()=>error=e.toString());}
    finally {if(mounted)setState(()=>busy=false);}
  }
  Widget leaf(String name,String role)=>Padding(
    padding:const EdgeInsets.only(left:28),
    child:Container(decoration:BoxDecoration(border:Border(left:BorderSide(color:Theme.of(context).colorScheme.outlineVariant,width:2))),
      child:ListTile(leading:const Icon(Icons.person_outline),title:Text(name),subtitle:Text(role))));
  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.only(left:16),
    decoration:BoxDecoration(border:Border(left:BorderSide(color:Theme.of(context).colorScheme.outlineVariant,width:2))),
    child:Card(child:ExpansionTile(
      leading:const Icon(Icons.account_tree_outlined),title:Text(widget.circle.name),
      subtitle:Text('${widget.circle.members.length} members${widget.privateCount>0?' · ${widget.privateCount} private contacts':''}'),
      children:[
        Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:widget.onMessages,icon:const Icon(Icons.chat_bubble_outline),label:Text(widget.unread>0?'Messages (${widget.unread})':'Messages'))),
        for(final member in widget.circle.members)leaf(member.person.displayName,member.creator?'Creator':member.admin?'Admin':'Member'),
        if(widget.privateCount>0)Padding(padding:const EdgeInsets.all(8),child:OutlinedButton(onPressed:busy||(loaded&&cursor==null)?null:loadContacts,child:Text(busy?'Loading…':!loaded?'Show private contacts (${widget.privateCount})':cursor!=null?'Load more contacts':'All contacts shown'))),
        if(error!=null)Padding(padding:const EdgeInsets.all(12),child:Text(error!,semanticsLabel:'Contact loading error: $error')),
        for(final contact in contacts)leaf((contact['displayName'] as String?)?.trim().isNotEmpty==true?contact['displayName'] as String:((contact['emails'] as List?)?.firstOrNull??(contact['phones'] as List?)?.firstOrNull??'Contact').toString(),'Private contact'),
      ],
    )),
  );
}
