import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:release_status/cloud/apple_sign_in.dart';
import 'package:release_status/cloud/cloud_config.dart';
import 'package:release_status/cloud/cloud_session.dart';
import 'package:release_status/cloud/google_sign_in.dart';
import 'package:release_status/widgets/app_wordmark.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onAuthenticated});

  final Future<void> Function() onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _creatingAccount = false;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _showApple {
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isPhone = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isPhone ? 24 : 28,
                isPhone ? 28 : 40,
                isPhone ? 24 : 28,
                24,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppWordmark(),
                      const SizedBox(height: 28),
                      Text(
                        _creatingAccount
                            ? 'CREATE ACCOUNT'
                            : 'Log in to your account to continue.',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: _creatingAccount ? 0.4 : 0,
                        ),
                      ),
                      if (_creatingAccount) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Sign up to back up your titles.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      TextFormField(
                        key: const ValueKey<String>('login-email-field'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (!email.contains('@')) {
                            return 'Enter a valid email.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey<String>('login-password-field'),
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: _creatingAccount
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (_creatingAccount) {
                            _signUp();
                          } else {
                            _signIn();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';
                          if (password.length < 6) {
                            return 'Use at least 6 characters.';
                          }
                          return null;
                        },
                      ),
                      if (!_creatingAccount) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _submitting ? null : _forgotPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 12),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_info != null) ...[
                        Text(
                          _info!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        key: const ValueKey<String>('login-submit-button'),
                        onPressed: _submitting
                            ? null
                            : (_creatingAccount ? _signUp : _signIn),
                        child: _submitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_creatingAccount ? 'Sign Up' : 'Sign In'),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton(
                        key: const ValueKey<String>('login-google-button'),
                        onPressed: _submitting ? null : _signInWithGoogle,
                        child: const Text('Continue with Google'),
                      ),
                      if (_showApple) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          key: const ValueKey<String>('login-apple-button'),
                          onPressed: _submitting ? null : _signInWithApple,
                          child: const Text('Continue with Apple'),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _creatingAccount
                                ? 'Already have an account? '
                                : "Don't have an account? ",
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            key: const ValueKey<String>(
                              'login-toggle-mode-button',
                            ),
                            onPressed: _submitting
                                ? null
                                : () {
                                    setState(() {
                                      _creatingAccount = !_creatingAccount;
                                      _error = null;
                                      _info = null;
                                    });
                                  },
                            child: Text(
                              _creatingAccount ? 'Sign In' : 'Sign Up',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _run(() async {
      final client = _client();
      await client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await widget.onAuthenticated();
    });
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _run(() async {
      final client = _client();
      final response = await client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        emailRedirectTo: CloudConfig.authRedirectUrl,
      );
      if (response.user == null) {
        throw const AuthException('Could not create account.');
      }
      if (response.session != null) {
        await widget.onAuthenticated();
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _creatingAccount = false;
        _info =
            'Account created. Open the confirmation link in your email, then sign in here.';
      });
    });
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _error = 'Enter your email above first.';
        _info = null;
      });
      return;
    }
    await _run(() async {
      final client = _client();
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: CloudConfig.authRedirectUrl,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _info = 'Password reset link sent. Open it on this device.';
      });
    });
  }

  Future<void> _signInWithApple() async {
    await _run(() async {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        throw const AuthException(
          'Sign in with Apple is not available on this device.',
        );
      }
      await signInToReleaseStatusWithApple(_client());
      await widget.onAuthenticated();
    });
  }

  Future<void> _signInWithGoogle() async {
    await _run(() async {
      await signInToReleaseStatusWithGoogle(_client());
      if (supportsNativeGoogleSignIn) {
        await widget.onAuthenticated();
      } else if (mounted) {
        setState(() {
          _info = 'Finish Google sign-in in the browser window.';
        });
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
      TextInput.finishAutofillContext();
    }
  }

  SupabaseClient _client() {
    final client = releaseStatusCloudClient();
    if (client == null) {
      throw const AuthException('Cloud login is not configured.');
    }
    return client;
  }
}
