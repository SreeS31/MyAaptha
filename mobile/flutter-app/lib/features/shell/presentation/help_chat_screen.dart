import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class HelpChatScreen extends StatefulWidget {
  const HelpChatScreen({super.key, required this.api,this.initialQuestion});
  final MyAapthaApi api;
  final String? initialQuestion;
  @override
  State<HelpChatScreen> createState() => _HelpChatScreenState();
}

class _HelpChatScreenState extends State<HelpChatScreen> {
  final question = TextEditingController();
  final scroll = ScrollController();
  final List<Map<String, dynamic>> messages = [];
  List<String> suggestions = [];
  bool configured = false, useAi = false, busy = false, enhanced = false, admin = false;
  String? error;
  @override
  void initState() { super.initState(); question.text=widget.initialQuestion??''; load(); }
  Future<void> load() async {
    try {
      final status = await widget.api.helpStatus();
      if (!mounted) return;
      setState(() { configured = status['aiConfigured'] == true; enhanced = status['enhancedEnabled'] == true; admin = status['canManage'] == true; suggestions = List<String>.from(status['questions'] as List); });
    } catch (_) { if (mounted) setState(() => error = 'Help is unavailable. Please try again.'); }
  }
  @override
  void dispose() { question.dispose(); scroll.dispose(); super.dispose(); }
  void scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
  });
  Future<void> send() async {
    final text = question.text.trim();
    if (text.isEmpty || busy) return;
    final history = messages.skip(messages.length > 4 ? messages.length - 4 : 0).map((m) {
      final content = m['content'] as String;
      return {'role': m['role'] as String, 'content': content.length > 2500 ? content.substring(0, 2500) : content};
    }).toList();
    setState(() { busy = true; error = null; if (messages.length >= 20) messages.removeRange(0, messages.length - 19); messages.add({'role':'user','content':text}); question.clear(); });
    scrollDown();
    try {
      final reply = await widget.api.askHelp(text, history, useAi);
      if (!mounted) return;
      setState(() => messages.add({'role':'assistant','content':reply['answer'],'reply':reply,'question':text}));
    } catch (failure) {
      if (mounted) setState(() { error = failure.toString(); question.text = text; });
    } finally { if (mounted) { setState(() => busy = false); scrollDown(); } }
  }
  Future<void> retry(String id, String text) async {
    if(busy)return;
    setState(() {busy=true;error=null;});
    try {
      final reply=await widget.api.retryHelp(id);
      if(mounted)setState(()=>messages.add({'role':'assistant','content':reply['answer'],'reply':reply,'question':text}));
    }catch(failure){if(mounted)setState(()=>error=failure.toString());}
    finally{if(mounted){setState(()=>busy=false);scrollDown();}}
  }
  Future<void> clear() async {
    setState(()=>busy=true);
    try{await widget.api.clearHelpHistory();if(mounted)setState(()=>messages.clear());}
    catch(_){if(mounted)setState(()=>error='Could not delete saved chat. Please try again.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> changeEnhanced(bool enabled) async {
    setState(()=>busy=true);
    try{await widget.api.setHelpEnhanced(enabled);if(mounted)setState(()=>enhanced=enabled);}
    catch(_){if(mounted)setState(()=>error='Could not update administrator settings.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> reviewAnswer(Map<String,dynamic> message) async {
    final questionField=TextEditingController(text:message['question'] as String? ?? '');
    final answerField=TextEditingController(text:message['content'] as String);
    bool confirmed=false;
    final accepted=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
      title:const Text('Review a public help answer'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('Remove private information and verify the answer against its sources. Shared answers expire after 30 days or a help-guide update.'),
        TextField(controller:questionField,maxLength:1200,decoration:const InputDecoration(labelText:'General question')),
        TextField(controller:answerField,maxLength:5000,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Reviewed answer')),
        CheckboxListTile(value:confirmed,onChanged:(v)=>update(()=>confirmed=v??false),title:const Text('Correct and contains no private information')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:confirmed?()=>Navigator.pop(ctx,true):null,child:const Text('Publish'))],
    )));
    final q=questionField.text.trim(), a=answerField.text.trim();
    // Wait until the dialog route finishes before disposing controllers used by its transition.
    await Future<void>.delayed(const Duration(milliseconds:300));
    questionField.dispose();answerField.dispose();
    if(accepted!=true||!mounted)return;
    setState(()=>busy=true);
    try{await widget.api.publishHelpAnswer(q,a,(message['reply']['sources'] as List).map((s)=>s['id'] as String).toList());}
    catch(_){if(mounted)setState(()=>error='Could not publish the reviewed answer.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ask MyAaptha'), actions: [IconButton(tooltip:'Clear chat', onPressed: busy ? null : clear, icon:const Icon(Icons.delete_outline))]),
    body: SafeArea(child: Column(children: [
      Expanded(child: ListView(controller:scroll, padding:const EdgeInsets.all(16), children:[
        const Text('Answers from MyAaptha’s application help.', style:TextStyle(fontWeight:FontWeight.w500,fontSize: 14)),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Use OpenAI answers'),value:useAi,onChanged:configured && !busy ? (value)=>setState(()=>useAi=value) : null),
        Text(configured ? 'When enabled, your question and recent chat are sent to OpenAI. Avoid passwords and private records.' : 'Application help is available. OpenAI conversation awaits operator configuration.'),
        const Text('Questions and replies are saved privately according to AI controls retention. Clear chat deletes saved help history. Only administrator-reviewed general answers are shared. This assistant cannot perform actions.'),
        if(admin) ExpansionTile(title:const Text('Administrator: AI cost controls'),children:[
          SwitchListTile(title:const Text('Allow users to try a stronger model'),subtitle:const Text('User chooses each retry. Maximum two paid stronger retries per user per 24 hours.'),value:enhanced,onChanged:busy?null:changeEnhanced),
          TextButton(onPressed:busy?null:()async{setState(()=>busy=true);try{await widget.api.clearSharedHelp();}catch(_){if(mounted)setState(()=>error='Could not clear shared answers.');}finally{if(mounted)setState(()=>busy=false);}},child:const Text('Clear shared answer cache')),
        ]),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:8,children:suggestions.map((s)=>ActionChip(label:Text(s),onPressed:busy?null:()=>setState(()=>question.text=s))).toList()),
        const SizedBox(height:16),
        for(final message in messages) Card(color:message['role']=='user'?Theme.of(context).colorScheme.primaryContainer:null,child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(message['role']=='user'?'You':message['reply']['mode']=='CACHE'?'MyAaptha saved answer':message['reply']['mode']=='AI'?'MyAaptha AI':'MyAaptha help',style:const TextStyle(fontWeight:FontWeight.w500)),
          const SizedBox(height:8),SelectableText(message['content'] as String),
          if(message['reply']!=null) ...[
            if(admin && (message['reply']['sources'] as List).isNotEmpty) TextButton(onPressed:busy?null:()=>reviewAnswer(message),child:const Text('Review for shared answers')),
            if(enhanced && configured && message['reply']['exchangeId']!=null && message['reply']['tier']=='BASE' && message['reply']['mode']!='HELP')
              TextButton(onPressed:busy?null:()=>retry(message['reply']['exchangeId'] as String,message['question'] as String? ?? ''),child:const Text('Not satisfied? Try stronger model')),
            if((message['reply']['notice'] as String).isNotEmpty) Padding(padding:const EdgeInsets.only(top:8),child:Text(message['reply']['notice'] as String)),
            for(final source in message['reply']['sources'] as List) ExpansionTile(tilePadding:EdgeInsets.zero,title:Text('Source: ${source['title']}'),children:[Padding(padding:const EdgeInsets.all(8),child:SelectableText(source['content'] as String))]),
          ],
        ]))),
        if(busy) const Padding(padding:EdgeInsets.all(12),child:Text('Finding an answer…')),
        if(error!=null) Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      ])),
      Padding(padding:const EdgeInsets.fromLTRB(16,8,16,12),child:Column(children:[
        TextField(controller:question,enabled:!busy,maxLength:1200,minLines:1,maxLines:3,decoration:const InputDecoration(labelText:'Your question',hintText:'How do I add a new relation?'),onSubmitted:(_)=>send()),
        Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:busy?null:send,icon:const Icon(Icons.send_outlined),label:Text(busy?'Answering…':'Ask'))),
      ])),
    ])),
  );
}
