import 'package:flutter/material.dart';
const uploadExpiryOptions=<int,String>{
 1:'1 day',7:'7 days',30:'30 days',60:'60 days',90:'90 days',180:'180 days',
 365:'1 year (365 days)',730:'2 years (730 days)',1095:'3 years (1,095 days)',
 1825:'5 years (1,825 days)',3650:'10 years (3,650 days)',0:'Never',
};
Future<int?> chooseUploadRetention(BuildContext context, Map<String,dynamic> level) async {
 final available=level['retentionDaysOptions'] as List<dynamic>?;
 final options=uploadExpiryOptions.entries.where((entry)=>available==null||available.contains(entry.key)).toList();
 var selected=0;
 return showDialog<int>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setState)=>AlertDialog(
  title:const Text('Keep this attachment'),
  content:Column(mainAxisSize:MainAxisSize.min,children:[
   const Text('Choose when this file expires. Never keeps it until you delete it. Expiring files stop downloading at the deadline and are queued for deletion. Downloaded copies are not affected.'),
   DropdownButtonFormField<int>(initialValue:selected,isExpanded:true,decoration:const InputDecoration(labelText:'Delete after'),items:[for(final option in options)DropdownMenuItem(value:option.key,child:Text(option.value))],onChanged:(value){if(value!=null)setState(()=>selected=value);}),
  ]),
  actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,selected),child:const Text('Continue upload'))],
 )));
}
