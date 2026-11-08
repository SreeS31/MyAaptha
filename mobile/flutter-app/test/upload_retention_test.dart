import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/upload_retention_dialog.dart';
void main(){
 testWidgets('active files never expire even with an older finite-only policy', (tester) async {
  int? chosen;
  await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>TextButton(onPressed:()async{chosen=await chooseUploadRetention(context,{'allowNever':false,'maxRetentionDays':7});},child:const Text('Upload')))));
  await tester.tap(find.text('Upload'));await tester.pumpAndSettle();
  expect(chosen,0);expect(find.byType(AlertDialog),findsNothing);
 });
}
