import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/core/theme/app_theme.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/application_settings_screen.dart';

class DesignSettingsApi extends MyAapthaApi {
  DesignSettingsApi() : super(AuthTokenBundle(tokenType: 'Bearer', accessToken: 'fixture', refreshToken: 'fixture', expiresIn: 900));
  int saves = 0;
  final settings = <String, dynamic>{'timeZone': 'Asia/Kolkata', 'quietStart': '22:00', 'quietEnd': '07:00'};
  @override Future<Map<String, dynamic>> applicationSettings() async => Map.from(settings);
  @override Future<Map<String, dynamic>> notificationPreferences() async => {};
  @override Future<Map<String, dynamic>> updateApplicationSettings(Map<String, dynamic> value) async { saves++; return Map.from(value); }
  @override Future<Map<String, dynamic>> updateNotificationPreferences(Map<String, dynamic> value) async => value;
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('settings remain readable and saveable at 320px and text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = DesignSettingsApi();
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!), home: ApplicationSettingsScreen(api: api)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Save settings'), 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final save = find.widgetWithText(FilledButton, 'Save settings');
      expect(tester.getSize(save).height, greaterThanOrEqualTo(44));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.saves, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
