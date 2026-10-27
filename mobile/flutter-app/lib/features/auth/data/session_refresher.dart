import 'auth_api.dart';
import 'session_store.dart';
import '../models/auth_models.dart';

class SessionRefresher {
  SessionRefresher({
    Future<AuthTokenBundle> Function(String)? refresh,
    Future<void> Function(AuthTokenBundle)? persist,
  })  : _refresh = refresh ??
            ((token) => AuthApi().refresh(RefreshRequest(refreshToken: token))),
        _persist = persist ?? SessionStore().save;

  static final shared = SessionRefresher();
  final Future<AuthTokenBundle> Function(String) _refresh;
  final Future<void> Function(AuthTokenBundle) _persist;
  final _pending = Expando<Future<String>>();

  Future<String> accessToken(AuthTokenBundle session) {
    final pending = _pending[session];
    if (pending != null) return pending;
    if (!session.needsRefresh) return Future.value(session.accessToken);
    final operation = Future<String>.microtask(() => _renew(session));
    _pending[session] = operation;
    return operation;
  }

  Future<String> _renew(AuthTokenBundle session) async {
    try {
      final updated = await _refresh(session.refreshToken)
          .timeout(const Duration(seconds: 15));
      session.replaceWith(updated);
      await _persist(session);
      return session.accessToken;
    } finally {
      _pending[session] = null;
    }
  }
}
