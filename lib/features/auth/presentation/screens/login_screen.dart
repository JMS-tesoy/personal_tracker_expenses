import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.isPasswordRecovery = false});

  final bool isPasswordRecovery;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _authRedirectUrl =
      'com.example.personaltrackerexpenses://login-callback/';

  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  late bool _isPasswordRecovery = widget.isPasswordRecovery;

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPasswordRecovery && !oldWidget.isPasswordRecovery) {
      _passwordController.clear();
      _confirmPasswordController.clear();
      _isPasswordRecovery = true;
      _isSignUp = false;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isPasswordRecovery) {
      await _updatePassword();
      return;
    }

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await _supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _authRedirectUrl,
        );
        if (!mounted) return;
        _passwordController.clear();
        setState(() => _isSignUp = false);
        _showMessage('Account created. Check your email, then sign in.');
      } else {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        _isSignUp ? 'Failed to create account.' : 'Failed to sign in.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Enter your email first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: _authRedirectUrl,
      );
      if (!mounted) return;
      _showMessage('Password reset email sent. Check your inbox.');
    } on AuthException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to send reset email.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Enter and confirm your new password.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.auth.updateUser(UserAttributes(password: password));
      await _supabase.auth.signOut();
      if (!mounted) return;
      _passwordController.clear();
      _confirmPasswordController.clear();
      setState(() => _isPasswordRecovery = false);
      _showMessage('Password updated. Please sign in again.');
    } on AuthException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to update password.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 56,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isPasswordRecovery ? 'Set New Password' : 'Payday Tracker',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!_isPasswordRecovery) ...<Widget>[
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onSubmitted: (_) {
                      if (!_isLoading) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: _isPasswordRecovery
                          ? 'New password'
                          : 'Password',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                      ),
                    ),
                  ),
                  if (_isPasswordRecovery) ...<Widget>[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscurePassword,
                      onSubmitted: (_) {
                        if (!_isLoading) _submit();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: Text(
                      _isLoading
                          ? 'Please wait...'
                          : _isPasswordRecovery
                          ? 'Update Password'
                          : _isSignUp
                          ? 'Create Account'
                          : 'Sign In',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!_isPasswordRecovery) ...<Widget>[
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Sign in'
                            : 'Create a new account',
                      ),
                    ),
                    if (!_isSignUp)
                      TextButton(
                        onPressed: _isLoading ? null : _sendPasswordResetEmail,
                        child: const Text('Forgot password?'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
