import 'package:flutter/material.dart';

class PostOptionsSheet extends StatefulWidget {
  const PostOptionsSheet({super.key,required this.post});
  final Map<String,dynamic> post;
  @override State<PostOptionsSheet> createState()=>_PostOptionsSheetState();
}
class _PostOptionsSheetState extends State<PostOptionsSheet>{
  bool more=false;
  final custom=TextEditingController();
  static const quick=['👍','❤️','😂','😮','😢','🙏'];
  static const extra=['😀','🥰','😍','🤗','🥳','🤔','🤣','😭','😡','💔','💯','🎉','👏','🙌','💪','👌','🤝','🌹','🌟','🔥','✅','🫶'];
  @override void dispose(){custom.dispose();super.dispose();}
  void select(String value)=>Navigator.pop(context,value);
  Widget emoji(String value)=>IconButton(tooltip:'React $value',onPressed:()=>select('reaction:${widget.post['myReaction']==value?'':value}'),icon:Text(value,style:const TextStyle(fontSize:24)));
  @override Widget build(BuildContext context){final p=widget.post;return SafeArea(child:SingleChildScrollView(padding:EdgeInsets.fromLTRB(12,0,12,MediaQuery.viewInsetsOf(context).bottom+12),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Wrap(alignment:WrapAlignment.center,children:[...quick.map(emoji),IconButton(tooltip:'More reactions',onPressed:()=>setState(()=>more=!more),icon:const Icon(Icons.add))]),
    if(more)...[Wrap(children:extra.map(emoji).toList()),Row(children:[Expanded(child:TextField(controller:custom,onChanged:(_)=>setState((){}),maxLength:32,decoration:const InputDecoration(labelText:'Custom emoji reaction'))),TextButton(onPressed:custom.text.trim().isEmpty?null:()=>select('reaction:${custom.text.trim()}'),child:const Text('React'))])],
    for(final item in <(String,String,IconData)>[
      ('info','Post info',Icons.info_outline),('reply','Reply',Icons.reply),('copy','Copy',Icons.copy),('react','React',Icons.add_reaction_outlined),('download','Download',Icons.download_outlined),('forward','Forward',Icons.forward),('pin',p['pinned']==true?'Unpin for me':'Pin for me',Icons.push_pin_outlined),('ask','Ask MyAaptha',Icons.auto_awesome_outlined),('star',p['savedByMe']==true?'Unstar':'Star',Icons.star_outline),
      if(p['mine']==true)...[('edit','Edit',Icons.edit_outlined),('delete','Delete',Icons.delete_outline)] else ('report','Report',Icons.flag_outlined)
    ])ListTile(dense:true,leading:Icon(item.$3),title:Text(item.$2),onTap:()=>item.$1=='react'?setState(()=>more=!more):select(item.$1))
  ])));}
}
