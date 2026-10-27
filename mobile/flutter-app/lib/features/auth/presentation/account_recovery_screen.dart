import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/auth_api.dart';

Future<bool> openPhoneVerification(Uri uri)=>launchUrl(uri,mode:LaunchMode.externalApplication);

class AccountRecoveryScreen extends StatefulWidget {
  const AccountRecoveryScreen({super.key,required this.api});
  final AuthApi api;
  @override State<AccountRecoveryScreen> createState()=>_AccountRecoveryScreenState();
}
class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  final form=GlobalKey<FormState>();
  final phone=TextEditingController(),code=TextEditingController(),password=TextEditingController();
  PhoneVerificationPolicy? policy;
  bool busy=false,loading=true;
  String? error,message;
  @override void initState(){super.initState();load();}
  @override void dispose(){phone.dispose();code.dispose();password.dispose();super.dispose();}
  Future<void> load() async {
    setState((){loading=true;error=null;});
    try {final result=await widget.api.securityPolicy();if(mounted)setState(()=>policy=result);}
    catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> requestCode() async {
    try {if(!await openPhoneVerification(policy!.verificationUri!))throw const AuthApiException('Could not open phone verification.');}
    catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  Future<void> submit() async {
    if(busy||policy?.configured!=true||!form.currentState!.validate())return;
    setState((){busy=true;error=null;message=null;});
    try {await widget.api.resetPassword(phone.text,code.text,password.text);if(mounted){code.clear();password.clear();setState(()=>message='If this is an eligible account, its password has been updated. You can now sign in.');}}
    catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Recover account')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(20),children:[
    if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
    if(policy==null)TextButton(onPressed:load,child:const Text('Retry account policy'))
    else if(!policy!.configured)const Text('Verified recovery is not configured. Contact your account support operator.')
    else Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('Verify your registered mobile number. Administrator recovery is handled by your authorized account operator.'),
      TextButton.icon(onPressed:busy?null:requestCode,icon:const Icon(Icons.open_in_new),label:const Text('Request SMS code')),
      TextFormField(controller:phone,enabled:!busy,keyboardType:TextInputType.phone,maxLength:32,decoration:const InputDecoration(labelText:'Registered mobile number'),validator:(v)=>v==null||!RegExp(r'^\+?[0-9 ()-]{7,32}$').hasMatch(v.trim())?'Enter a valid mobile number':null),
      TextFormField(controller:code,enabled:!busy,keyboardType:TextInputType.number,autofillHints:const [AutofillHints.oneTimeCode],maxLength:10,decoration:const InputDecoration(labelText:'SMS verification code'),validator:(v)=>v==null||!RegExp(r'^\d{4,10}$').hasMatch(v.trim())?'Enter the SMS code':null),
      TextFormField(controller:password,enabled:!busy,obscureText:true,maxLength:128,autofillHints:const [AutofillHints.newPassword],decoration:const InputDecoration(labelText:'New password'),validator:(v)=>v==null||v.length<8||!RegExp('[A-Za-z]').hasMatch(v)||!RegExp('[0-9]').hasMatch(v)?'Use at least 8 characters with letters and numbers':null),
      FilledButton(onPressed:busy?null:submit,child:Text(busy?'Updating…':'Set new password')),
      if(message!=null)Semantics(liveRegion:true,child:Text(message!)),
    ])),
  ]));
}
