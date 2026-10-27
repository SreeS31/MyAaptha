import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/features/shell/presentation/post_options_sheet.dart';

void main(){
 testWidgets('owner menu exposes functional action choices and a quick reaction result',(tester)async{
  String? result;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:()async{result=await showModalBottomSheet<String>(context:context,isScrollControlled:true,builder:(_)=>const PostOptionsSheet(post:{'mine':true}));},child:const Text('Open'))))));
  await tester.tap(find.text('Open'));await tester.pumpAndSettle();
  for(final label in ['Post info','Reply','Copy','React','Download','Forward','Pin for me','Ask MyAaptha','Star','Edit','Delete']){expect(find.text(label),findsOneWidget);}
  await tester.tap(find.byTooltip('React ❤️'));await tester.pumpAndSettle();expect(result,'reaction:❤️');
 });
 testWidgets('other authors cannot be edited or deleted and current reaction can be removed',(tester)async{
  String? result;
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:()async{result=await showModalBottomSheet<String>(context:context,isScrollControlled:true,builder:(_)=>const PostOptionsSheet(post:{'mine':false,'pinned':true,'savedByMe':true,'myReaction':'👍'}));},child:const Text('Open'))))));
  await tester.tap(find.text('Open'));await tester.pumpAndSettle();expect(find.text('Report'),findsOneWidget);expect(find.text('Edit'),findsNothing);expect(find.text('Delete'),findsNothing);expect(find.text('Unpin for me'),findsOneWidget);expect(find.text('Unstar'),findsOneWidget);
  await tester.tap(find.byTooltip('React 👍'));await tester.pumpAndSettle();expect(result,'reaction:');
 });
}
