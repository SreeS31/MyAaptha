import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/upload_retention_dialog.dart';
void main(){
 const choices=[1,7,30,60,90,180,365,730,1095,1825,3650,0];
 for(final days in [0,7,3650]){
  testWidgets('upload expiry selects $days days with Never as default', (tester) async {
   int? chosen;
   await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>TextButton(onPressed:()async{chosen=await chooseUploadRetention(context,{'retentionDaysOptions':choices});},child:const Text('Upload')))));
   await tester.tap(find.text('Upload'));await tester.pumpAndSettle();
   final field=find.byType(DropdownButtonFormField<int>);
   expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).items!.map((item)=>item.value).toList(),choices);
   expect(find.text('Never'),findsOneWidget);
   if(days!=0){
    await tester.tap(field);await tester.pumpAndSettle();
    final option=find.text(uploadExpiryOptions[days]!).last.hitTestable();
    for(var attempt=0;attempt<20&&option.evaluate().isEmpty;attempt++){await tester.drag(find.byType(Scrollable).last,const Offset(0,80));await tester.pumpAndSettle();}
    expect(option,findsOneWidget);await tester.tap(option);await tester.pumpAndSettle();
   }
   await tester.tap(find.text('Continue upload'));await tester.pumpAndSettle();
   expect(chosen,days);expect(find.byType(AlertDialog),findsNothing);
  });
 }
 testWidgets('cancelling the expiry choice cancels the upload', (tester) async {
  int? chosen=-1;
  await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>TextButton(onPressed:()async{chosen=await chooseUploadRetention(context,{});},child:const Text('Upload')))));
  await tester.tap(find.text('Upload'));await tester.pumpAndSettle();
  await tester.tap(find.text('Cancel'));await tester.pumpAndSettle();expect(chosen,isNull);
 });
}
