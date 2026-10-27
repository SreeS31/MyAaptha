import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/widgets/info_help.dart';

void main(){
  for(final scale in [1.0,1.7]){
    testWidgets('inline help is compact and opens full guidance at text scale $scale',(tester)async{
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:MediaQuery(
        data:MediaQueryData(textScaler:TextScaler.linear(scale)),
        child:const Align(alignment:Alignment.topLeft,child:SizedBox(width:320,child:InfoHelpLabel(
          title:'Storage limits',message:'Each file can use up to 25 MB.',
        ))),
      ))));
      expect(tester.getSize(find.byType(InfoHelpLabel)).height,lessThan(70));
      expect(tester.getSize(find.byType(IconButton)).width,inInclusiveRange(40,48));
      await tester.tap(find.byTooltip('About storage limits'));
      await tester.pumpAndSettle();
      expect(find.text('Each file can use up to 25 MB.'),findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog),findsNothing);
      expect(tester.takeException(),isNull);
    });
  }
}
