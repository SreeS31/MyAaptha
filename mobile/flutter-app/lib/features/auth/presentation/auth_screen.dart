import 'package:myaaptha_mobile/features/auth/data/auth_api.dart';
import 'package:myaaptha_mobile/features/auth/data/session_store.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:flutter/material.dart';

enum AuthMode { signIn, signUp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});
  final ValueChanged<AuthTokenBundle> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthApi _authApi = AuthApi();
  final SessionStore _sessionStore = SessionStore();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  AuthMode _authMode = AuthMode.signIn;
  AuthTokenBundle? _session;
  bool _loading = false;
  String _statusMessage = 'Ready';

  String _normalizeSignInIdentifier(String value) {
    final identifier = value.trim();
    if (identifier.contains('@') || RegExp(r'[A-Za-z]').hasMatch(identifier)) {
      return identifier;
    }

    final compact = identifier.replaceAll(RegExp(r'[\s()-]'), '');
    if (RegExp(r'^\d{10}$').hasMatch(compact)) {
      return '+91$compact';
    }
    return compact;
  }

  @override
  void initState() {
    super.initState();
    _probeAuthService();
    _restoreSessionIfAvailable();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _probeAuthService() async {
    try {
      final health = await _authApi.checkHealth();
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Auth service: ${health.status}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Auth service unavailable';
      });
    }
  }

  Future<void> _restoreSessionIfAvailable() async {
    final existingSession = await _sessionStore.load();
    if (existingSession == null) {
      return;
    }

    try {
      final refreshed = await _authApi.refresh(
        RefreshRequest(refreshToken: existingSession.refreshToken),
      );
      await _sessionStore.save(refreshed);
      _session = refreshed;

      final summary = await _authApi.fetchDashboardSummary(
        refreshed.accessToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'Session restored | users=${summary.userCount} circles=${summary.circleCount}';
      });
      widget.onAuthenticated(refreshed);
    } catch (_) {
      await _sessionStore.clear();
      _session = null;
    }
  }

  Future<void> _logout() async {
    final session = _session;
    if (session == null) {
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = 'Signing out...';
    });

    try {
      await _authApi.logout(RefreshRequest(refreshToken: session.refreshToken));
    } catch (_) {
      // Clear local session even when remote logout call fails.
    }

    await _sessionStore.clear();
    if (!mounted) {
      return;
    }

    setState(() {
      _session = null;
      _loading = false;
      _statusMessage = 'Signed out';
    });
  }

  Future<void> _revokeSession() async {
    final session = _session;
    if (session == null) {
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = 'Revoking session...';
    });

    try {
      await _authApi.revoke(RefreshRequest(refreshToken: session.refreshToken));
    } catch (_) {
      // Clear local session even when remote revoke call fails.
    }

    await _sessionStore.clear();
    if (!mounted) {
      return;
    }

    setState(() {
      _session = null;
      _loading = false;
      _statusMessage = 'Session revoked';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = 'Submitting...';
    });

    try {
      if (_authMode == AuthMode.signUp) {
        final result = await _authApi.registerUser(
          RegisterUserRequest(
            username: _usernameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _statusMessage =
              'Registration created for ${result.username} (#${result.id})';
        });
      } else {
        final tokenBundle = await _authApi.login(
          LoginRequest(
            identifier: _normalizeSignInIdentifier(_emailController.text),
            password: _passwordController.text,
          ),
        );
        await _sessionStore.save(tokenBundle);
        _session = tokenBundle;

        final summary = await _authApi.fetchDashboardSummary(
          tokenBundle.accessToken,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _statusMessage =
              'Signed in successfully | users=${summary.userCount} circles=${summary.circleCount}';
        });
        widget.onAuthenticated(tokenBundle);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = error is AuthApiException
            ? (error.message.contains('401') ||
                      error.message.toLowerCase().contains('credential')
                  ? 'The mobile number/email or password is incorrect. Please check your details and try again.'
                  : error.message)
            : 'Unable to reach the server. Check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _authMode == AuthMode.signUp;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyAaptha Auth'),
        actions: [
          if (_session != null)
            TextButton(
              onPressed: _loading ? null : _revokeSession,
              child: const Text('Revoke'),
            ),
          if (_session != null)
            TextButton(
              onPressed: _loading ? null : _logout,
              child: const Text('Logout'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SegmentedButton<AuthMode>(
                segments: const [
                  ButtonSegment<AuthMode>(
                    value: AuthMode.signIn,
                    label: Text('Sign In'),
                  ),
                  ButtonSegment<AuthMode>(
                    value: AuthMode.signUp,
                    label: Text('Sign Up'),
                  ),
                ],
                selected: {_authMode},
                onSelectionChanged: (selected) {
                  setState(() {
                    _authMode = selected.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (isSignUp)
                TextFormField(
                  controller: _usernameController,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!isSignUp) {
                      return null;
                    }
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    if (!RegExp(
                      r'^[A-Za-z0-9._-]{3,64}$',
                    ).hasMatch(value.trim())) {
                      return 'Use 3-64 letters, numbers, dots, underscores, or hyphens';
                    }
                    return null;
                  },
                ),
              if (isSignUp) const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                maxLength: 254,
                decoration: InputDecoration(
                  labelText: isSignUp
                      ? 'Email (optional)'
                      : 'Email or mobile number',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (!isSignUp && (value == null || value.trim().isEmpty)) {
                    return 'Email or mobile number is required';
                  }
                  if (isSignUp &&
                      value != null &&
                      value.trim().isNotEmpty &&
                      !RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(value.trim())) {
                    return 'Enter a valid email';
                  }
                  if (!isSignUp && value != null && value.trim().length > 254) {
                    return 'Email or mobile number is too long';
                  }
                  return null;
                },
              ),
              if (isSignUp) const SizedBox(height: 12),
              if (isSignUp)
                TextFormField(
                  controller: _phoneController,
                  maxLength: 32,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Mobile number is required';
                    }
                    final digits = value.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 7 || digits.length > 15) {
                      return 'Enter a valid mobile number';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                maxLength: 128,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (isSignUp &&
                      (!RegExp(r'[A-Z]').hasMatch(value) ||
                          !RegExp(r'[a-z]').hasMatch(value) ||
                          !RegExp(r'\d').hasMatch(value))) {
                    return 'Use uppercase, lowercase, and a number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: Text(
                  _loading
                      ? 'Please wait...'
                      : (isSignUp ? 'Create Account' : 'Sign In'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
