import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/features/shell/presentation/page_discover.dart';

void main() {
  testWidgets('Discover finds current-page text and excludes inactive pages',
      (tester) async {
    final root = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            appBar: AppBar(actions: [PageDiscoverButton(root: root)]),
            body: KeyedSubtree(
                key: root,
                child: const IndexedStack(index: 0, children: [
                  SingleChildScrollView(child: Text('Office contacts')),
                  Text('Private hidden page')
                ])))));
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Office');
    await tester.pump();
    expect(find.widgetWithText(ListTile, 'Office contacts'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Private hidden');
    await tester.pump();
    expect(find.text('No matches on this page'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
