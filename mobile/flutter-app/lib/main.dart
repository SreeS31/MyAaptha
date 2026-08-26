import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/data/session_store.dart';

import 'app.dart';

const backgroundSyncTask = 'myaaptha-background-sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((_, __) async {
    WidgetsFlutterBinding.ensureInitialized();
    final session = await SessionStore().load();
    if (session == null) return true;
    final api = MyAapthaApi(session);
    try {
      await Future.wait([api.relationships(), api.circles(), api.profile()]);
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
      backgroundSyncTask, backgroundSyncTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected));
  runApp(const MyAapthaMobileApp());
}
