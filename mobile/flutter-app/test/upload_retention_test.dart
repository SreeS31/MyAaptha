import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/upload_retention_dialog.dart';
void main(){
 testWidgets('never default and finite retention validation', (tester) async {
  int? chosen;
  await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>TextButton(onPressed:()async{chosen=await chooseUploadRetention(context,{'allowNever':true,'maxRetentionDays':7});},child:const Text('Upload')))));
  await tester.tap(find.text('Upload'));await tester.pumpAndSettle();
  expect(tester.widget<Switch>(find.byType(Switch)).value,true);
  await tester.tap(find.text('Never expire'));await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField),'8');await tester.tap(find.text('Continue upload'));await tester.pumpAndSettle();expect(find.text('Choose 1-7 days'),findsOneWidget);
  await tester.enterText(find.byType(TextFormField),'3');await tester.tap(find.text('Continue upload'));await tester.pumpAndSettle();await tester.pump(const Duration(seconds:2));expect(chosen,3);
 });
}
