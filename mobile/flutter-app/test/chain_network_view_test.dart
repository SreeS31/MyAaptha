import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/chain_network_view.dart';

void main() {
  testWidgets(
      'details do not expand a branch; chain action reaches the next person',
      (tester) async {
    final relations = [
      Relationship(
          id: 1,
          type: 'Friend',
          person: Person(
              id: 1,
              displayName: 'Alex',
              accountStatus: 'ACTIVE',
              gender: 'MALE'),
          visibilityScope: 'FRIENDS'),
      Relationship(
          id: 2,
          type: 'Sister',
          relativeToUserId: 1,
          person: Person(
              id: 2,
              displayName: 'Maya',
              accountStatus: 'ACTIVE',
              gender: 'FEMALE'),
          visibilityScope: 'FRIENDS'),
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChainNetworkView(
                relationships: relations, profile: null, onDetails: (_) {}))));
    await tester.pumpAndSettle();
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Maya'), findsNothing);
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(find.text('Profile & relationship actions'), findsOneWidget);
    expect(find.text('Maya'), findsNothing);
    await tester.tap(find.text('Expand chain'));
    await tester.pumpAndSettle();
    expect(find.text('Maya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
