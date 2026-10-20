import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/radiant_logo.dart';
import '../../widgets/radiant_text_field.dart';
import 'validators.dart';

/// Authorized user sign in (Supabase email and password).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _confirmTouched = false;
  bool _busy = false;
  String? _serverError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _emailOk => Validators.isValidEmail(_email.text);
  bool get _passwordOk => Validators.isValidPassword(_password.text);
  bool get _confirmOk =>
      Validators.passwordsMatch(_password.text, _confirm.text);
  bool get _canSubmit => _emailOk && _passwordOk && _confirmOk && !_busy;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _serverError = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
      );
      await widget.appState.setRole(UserRole.admin);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _serverError = _friendly(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _serverError =
          'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login')) return 'Wrong email or password.';
    if (message.contains('not confirmed')) {
      return 'This account is not confirmed yet. Ask an admin to confirm it.';
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final emailStatus = !_emailTouched
        ? FieldStatus.neutral
        : (_emailOk ? FieldStatus.valid : FieldStatus.error);
    final passwordStatus = (_passwordTouched && !_passwordOk)
        ? FieldStatus.error
        : FieldStatus.neutral;
    final confirmStatus = !_confirmTouched
        ? FieldStatus.neutral
        : (_confirmOk ? FieldStatus.valid : FieldStatus.error);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: RadiantColors.textMuted,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const RadiantLogo(),
              const SizedBox(height: 20),
              const Text(
                'Authorized user sign in',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Admins and emergency vehicle personnel',
                style: TextStyle(
                  fontSize: 12,
                  color: RadiantColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              RadiantTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                status: emailStatus,
                message: emailStatus == FieldStatus.error
                    ? Validators.emailError(_email.text)
                    : (emailStatus == FieldStatus.valid ? 'Looks good' : null),
                onChanged: (_) => setState(() {
                  _emailTouched = true;
                  _serverError = null;
                }),
              ),
              const SizedBox(height: 14),
              RadiantTextField(
                label: 'Password',
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.password],
                status: passwordStatus,
                message: passwordStatus == FieldStatus.error
                    ? Validators.passwordError(_password.text)
                    : null,
                onChanged: (_) => setState(() {
                  _passwordTouched = true;
                  _serverError = null;
                }),
              ),
              const SizedBox(height: 14),
              RadiantTextField(
                label: 'Re-type password',
                controller: _confirm,
                obscure: true,
                textInputAction: TextInputAction.done,
                status: confirmStatus,
                message: confirmStatus == FieldStatus.error
                    ? Validators.confirmError(_password.text, _confirm.text)
                    : (confirmStatus == FieldStatus.valid
                        ? 'Passwords match'
                        : null),
                onChanged: (_) => setState(() {
                  _confirmTouched = true;
                  _serverError = null;
                }),
                onSubmitted: (_) => _submit(),
              ),
              if (_serverError != null) ...[
                const SizedBox(height: 14),
                Text(
                  _serverError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: RadiantColors.red,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: RadiantColors.green,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: RadiantColors.disabled,
                    disabledForegroundColor: RadiantColors.textMuted,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Sign in',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              if (_emailOk && _passwordOk && _confirmOk) ...[
                const SizedBox(height: 10),
                const Text(
                  'Both fields are valid. You can sign in.',
                  style: TextStyle(fontSize: 11, color: RadiantColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
