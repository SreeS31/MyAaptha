import 'package:flutter/material.dart';

class InfoHelp extends StatelessWidget {
  const InfoHelp({super.key,required this.title,required this.message});
  final String title,message;
  @override
  Widget build(BuildContext context)=>IconButton(
    tooltip:'About ${title.toLowerCase()}',
    constraints:const BoxConstraints.tightFor(width:40,height:40),
    padding:const EdgeInsets.all(8),
    icon:const Icon(Icons.info_outline_rounded,size:18),
    color:Theme.of(context).colorScheme.primary,
    onPressed:()=>showDialog<void>(context:context,builder:(context)=>AlertDialog(title:Text(title),content:SingleChildScrollView(child:Text(message)),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Done'))])),
  );
}

/// Keeps the information action beside its text, including at larger text scales.
class InfoHelpLabel extends StatelessWidget {
  const InfoHelpLabel({super.key,required this.title,required this.message,this.style});
  final String title,message;
  final TextStyle? style;
  @override
  Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[
    Flexible(child:Text(title,style:style)),
    InfoHelp(title:title,message:message),
  ]);
}
