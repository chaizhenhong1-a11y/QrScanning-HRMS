import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/auth/presentation/widgets/veyra_auth_shell.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your work email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.code == 'invalid-email'
            ? 'Enter a valid email address.'
            : error.message ?? 'Unable to send reset email.';
      });
    }
  }

  @override
  void dispose() {
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
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Back to sign in'),
      ),
      child: _sent
          ? const Icon(Icons.mark_email_read_outlined, size: 64)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  onSubmitted: (_) => _sendReset(),
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
}
