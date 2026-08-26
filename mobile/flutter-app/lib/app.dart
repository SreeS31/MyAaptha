import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/theme/app_theme.dart';
import 'package:myaaptha_mobile/features/auth/data/session_store.dart';
import 'package:myaaptha_mobile/features/auth/data/auth_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/auth/presentation/auth_screen.dart';
import 'package:myaaptha_mobile/features/shell/presentation/app_shell.dart';

class MyAapthaMobileApp extends StatefulWidget {
  const MyAapthaMobileApp({super.key});

  @override
  State<MyAapthaMobileApp> createState() => _MyAapthaMobileAppState();
}

class _MyAapthaMobileAppState extends State<MyAapthaMobileApp> {
  final SessionStore _store = SessionStore();
  AuthTokenBundle? _session;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreValidSession();
  }

  Future<void> _restoreValidSession() async {
    final saved = await _store.load();
    AuthTokenBundle? valid;
    if (saved != null) {
      try {
        valid = await AuthApi().refresh(
            RefreshRequest(refreshToken: saved.refreshToken));
        await _store.save(valid);
      } catch (_) {
        await _store.clear();
      }
    }
    if (mounted) setState(() { _session = valid; _restoring = false; });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyAaptha',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _restoring
          ? const _SplashScreen()
          : _session == null
              ? AuthScreen(
                  onAuthenticated: (session) =>
                      setState(() => _session = session))
              : AppShell(
                  session: _session!,
                  onSignedOut: () => setState(() => _session = null)),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF6251C8), Color(0xFFD47DA9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
          child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/brand/myaaptha-logo.png', width: 96, height: 96),
            const SizedBox(height: 16),
            const Text('MyAaptha',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.white)
          ])),
        ),
      );
}
