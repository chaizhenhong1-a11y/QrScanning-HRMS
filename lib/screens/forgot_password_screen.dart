import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/utils/firebase_error_message.dart';
import '../features/auth/presentation/widgets/veyra_auth_shell.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendCooldown = Duration(seconds: 30);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  Timer? _cooldownTimer;
  bool _loading = false;
  bool _sent = false;
  int _cooldownSeconds = 0;
  String? _error;

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Enter your work email.';
    }

    final atIndex = email.indexOf('@');
    final dotIndex = email.lastIndexOf('.');
    if (atIndex <= 0 ||
        dotIndex <= atIndex + 1 ||
        dotIndex == email.length - 1) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  Future<void> _sendReset() async {
    if (_loading || _cooldownSeconds > 0) {
      return;
    }

    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim().toLowerCase();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) {
        return;
      }
      _markSent();
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      // Avoid exposing whether an employee account exists for a work email.
      if (error.code == 'user-not-found') {
        _markSent();
        return;
      }

      setState(() {
        _loading = false;
        _error = firebaseErrorMessage(error);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = firebaseErrorMessage(error);
      });
    }
  }

  void _markSent() {
    _cooldownTimer?.cancel();
    setState(() {
      _loading = false;
      _sent = true;
      _error = null;
      _cooldownSeconds = _resendCooldown.inSeconds;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
        return;
      }

      setState(() => _cooldownSeconds -= 1);
    });
  }

  void _changeEmail() {
    _cooldownTimer?.cancel();
    setState(() {
      _sent = false;
      _loading = false;
      _cooldownSeconds = 0;
      _error = null;
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VeyraAuthShell(
      title: _sent ? 'Check your inbox' : 'Reset your password',
      subtitle: _sent
          ? 'If an account is available for that email, follow the reset instructions we sent.'
          : 'Enter your work email and Veyra will send a secure Firebase password reset link.',
      footer: TextButton.icon(
        onPressed: _loading ? null : () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Back to sign in'),
      ),
      child: _sent ? _buildSentState() : _buildResetForm(),
    );
  }

  Widget _buildResetForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            enabled: !_loading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            enableSuggestions: false,
            validator: _validateEmail,
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            onFieldSubmitted: (_) => _sendReset(),
            decoration: const InputDecoration(
              labelText: 'Work email',
              hintText: 'name@company.com',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            VeyraErrorBanner(_error!),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _sendReset,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }

  Widget _buildSentState() {
    final email = _emailController.text.trim().toLowerCase();
    final canResend = !_loading && _cooldownSeconds == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: Icon(Icons.mark_email_read_outlined, size: 64)),
        const SizedBox(height: 18),
        Text(
          email,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        FilledButton.tonalIcon(
          onPressed: canResend ? _sendReset : null,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(
            _cooldownSeconds > 0
                ? 'Send again in ${_cooldownSeconds}s'
                : 'Send again',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading ? null : _changeEmail,
          child: const Text('Use a different email'),
        ),
      ],
    );
  }
}
