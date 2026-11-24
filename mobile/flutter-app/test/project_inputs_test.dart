import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/project_inputs_screen.dart';

class InputsApi extends MyAapthaApi {
  InputsApi()
      : super(AuthTokenBundle(
            tokenType: 'Bearer',
            accessToken: 'test',
            refreshToken: 'test',
            expiresIn: 900));
  Map<String, dynamic> task = {
    'definition': {
      'key': 'encryption',
      'title': 'Encrypted messaging',
      'pendingWork': 'Implementation pending',
      'fields': [
        {
          'key': 'mode',
          'label': 'Chat encryption model',
          'kind': 'choice',
          'options': ['Undecided', 'Encrypted chats by default']
        }
      ]
    },
    'values': <String, dynamic>{},
    'ready': false,
    'version': 0
  };
  @override
  Future<List<Map<String, dynamic>>> projectInputs() async => [task];
  @override
  Future<Map<String, dynamic>> saveProjectInputs(
      String key, Map values, bool ready, int version) async {
    task = {
      ...task,
      'values': Map<String, dynamic>.from(values),
      'ready': ready,
      'version': version + 1
    };
    return task;
  }
}

void main() {
  testWidgets('owner can save setup choices for a later implementation pass',
      (tester) async {
    final api = InputsApi();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ProjectInputsScreen(api: api))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Encrypted chats by default').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
    await tester.pumpAndSettle();
    expect(api.task['version'], 1);
    expect(api.task['ready'], false);
    await tester.tap(find.widgetWithText(FilledButton, 'Ready for review'));
    await tester.pumpAndSettle();
    expect(api.task['ready'], true);
    expect(api.task['values']['mode'], 'Encrypted chats by default');
    expect(tester.takeException(), isNull);
  });
}
