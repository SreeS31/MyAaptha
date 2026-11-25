import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/app_shell.dart';

class ChoicesApi extends MyAapthaApi {
  ChoicesApi()
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'test',
            refreshToken: 'test',
            expiresIn: 900));
  String? chosenType, chosenScope;
  @override
  Future<Relationship> updateRelationship(
      Relationship relationship, String type, String visibility) async {
    chosenType = type;
    chosenScope = visibility;
    return relationship;
  }
}

void main() {
  testWidgets(
      'legacy relationship can be edited using eight family choices and combined View',
      (tester) async {
    final api = ChoicesApi();
    bool refreshed = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RelationshipTile(
                relationship: Relationship(
                    id: 1,
                    type: 'Friend',
                    visibilityScope: 'FRIENDS',
                    person: Person(
                        id: 2, displayName: 'Alex', accountStatus: 'ACTIVE')),
                api: api,
                onRemoved: () => refreshed = true))));
    await tester.tap(find.byTooltip('Person actions'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit relationship'));
    await tester.tap(find.text('Edit relationship'));
    await tester.pumpAndSettle();
    final picker = find.byType(DropdownButtonFormField<String>).first;
    final values = tester
        .widget<DropdownButton<String>>(find
            .descendant(
                of: picker, matching: find.byType(DropdownButton<String>))
            .first)
        .items!
        .map((i) => i.value)
        .toList();
    expect(values, [
      'Father',
      'Mother',
      'Brother',
      'Sister',
      'Wife',
      'Husband',
      'Son',
      'Daughter'
    ]);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mother').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Friends & relatives').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(api.chosenType, 'Mother');
    expect(api.chosenScope, 'FRIENDS_RELATIVES');
    expect(refreshed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
