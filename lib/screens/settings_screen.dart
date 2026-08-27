import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/firebase/firebase_services.dart';
import '../core/utils/firebase_error_message.dart';
import '../features/identity/application/identity_service.dart';
import '../features/identity/domain/hrms_role.dart';
import '../features/identity/domain/tenant_identity.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final IdentityService _identityService = IdentityService();

  TenantIdentity? _identity;
  bool _loading = true;
  bool _sendingReset = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final identity = await _identityService.restoreIdentity();
      if (!mounted) return;

      if (identity == null) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }

      setState(() {
        _identity = identity;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = firebaseErrorMessage(error);
      });
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_sendingReset) return;

    final firebaseUser = FirebaseServices.auth.currentUser;
    final email = firebaseUser?.email?.trim().toLowerCase();
    if (firebaseUser == null || email == null || email.isEmpty) {
      setState(() {
        _error = 'Your account email is unavailable. Please sign in again.';
      });
      return;
    }

    setState(() {
      _sendingReset = true;
      _error = null;
    });

    try {
      await FirebaseServices.auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset instructions were sent to $email.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = firebaseErrorMessage(error));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = firebaseErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _sendingReset = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _identity == null
          ? _buildLoadError()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _buildAccountCard(),
                  const SizedBox(height: 20),
                  _buildSecurityCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBanner(_error!),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    final identity = _identity!;
    return _sectionCard(
      title: 'Account',
      icon: Icons.badge_outlined,
      children: [
        _infoRow('Name', identity.displayName),
        _infoRow('Work email', identity.email),
        _infoRow('Employee ID', identity.employeeId),
        _infoRow('Department', identity.department),
        _infoRow('Role', _roleLabel(identity.role)),
        _infoRow('Company ID', identity.companyId),
      ],
    );
  }

  Widget _buildSecurityCard() {
    final email =
        FirebaseServices.auth.currentUser?.email ?? _identity?.email ?? '';
    return _sectionCard(
      title: 'Security',
      icon: Icons.shield_outlined,
      children: [
        const Text(
          'Password changes are completed through a secure email link.',
          style: TextStyle(color: Color(0xFF64748B), height: 1.45),
        ),
        const SizedBox(height: 14),
        if (email.isNotEmpty)
          Text(
            'Reset email: $email',
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _sendingReset ? null : _sendPasswordReset,
            icon: _sendingReset
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_reset_rounded),
            label: Text(
              _sendingReset ? 'Sending...' : 'Send Password Reset Email',
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4FACFE)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final display = value.trim().isEmpty ? 'Not available' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              display,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF991B1B)),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(HrmsRole role) {
    return switch (role) {
      HrmsRole.superAdmin => 'Super Admin',
      HrmsRole.companyOwner => 'Company Owner',
      HrmsRole.hrAdmin => 'HR Admin',
      HrmsRole.manager => 'Manager',
      HrmsRole.employee => 'Employee',
    };
  }
}
