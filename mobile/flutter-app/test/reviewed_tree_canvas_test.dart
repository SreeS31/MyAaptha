import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/features/shell/presentation/reviewed_tree_canvas.dart';

void main() {
  testWidgets(
      'all layouts preserve branch markers, gender colors and node selection',
      (tester) async {
    Map<String, dynamic>? selected;
    final nodes = <Map<String, dynamic>>[
      {
        'key': 'a',
        'name': 'Alex',
        'relation': 'Friend',
        'parentKey': null,
        'gender': 'MALE'
      },
      {
        'key': 'b',
        'name': 'Maya',
        'relation': 'Sister',
        'parentKey': 'a',
        'gender': 'FEMALE'
      },
      {'key': 'c', 'name': 'Robin', 'relation': 'Connection', 'parentKey': null}
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ReviewedTreeCanvas(
                    nodes: nodes,
                    selected: null,
                    onSelect: (n) => selected = n)))));
    expect(find.byTooltip('Expand Alex'), findsOneWidget);
    await tester.tap(find.byTooltip('Expand Alex'));
    await tester.pump();
    expect(find.bySemanticsLabel('Maya: end node'), findsOneWidget);
    for (final mode in ['Modern', 'Heritage', 'Compact', 'Right-growing']) {
      await tester.tap(find.widgetWithText(ChoiceChip, mode));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Alex'));
    await tester.pump();
    expect(selected?['key'], 'a');
    final icons = tester.widgetList<Icon>(find.byType(Icon));
    expect(icons.any((i) => i.color == const Color(0xff326bc4)), isTrue);
    expect(icons.any((i) => i.color == const Color(0xffbe3273)), isTrue);
  });
}
