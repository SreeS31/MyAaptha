import 'package:flutter/material.dart';
Future<int?> chooseUploadRetention(BuildContext context, Map<String,dynamic> level) async {
 final maximum=(level['maxRetentionDays'] as num).toInt();
 bool never=level['allowNever']==true;
 final days=TextEditingController(text: '${maximum < 30 ? maximum : 30}');
 final form=GlobalKey<FormState>();
 final result=await showDialog<int>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setState)=>AlertDialog(
  title:const Text('Keep this attachment'),
  content:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
   const Text('Choose when the server copy expires. Downloaded copies are not affected.'),
   if(level['allowNever']==true) SwitchListTile(title:const Text('Never expire'),value:never,onChanged:(value)=>setState(()=>never=value)),
   if(!never)TextFormField(controller:days,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Days (1-$maximum)'),validator:(value){final n=int.tryParse(value??'');return n==null||n<1||n>maximum?'Choose 1-$maximum days':null;})
  ])),
  actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:(){if(never||form.currentState!.validate())Navigator.pop(context,never?0:int.parse(days.text));},child:const Text('Continue upload'))]
 )));
 // Let the dialog finish its closing transition before disposing its controller.
 Future<void>.delayed(const Duration(seconds:1),days.dispose);
 return result;
}
