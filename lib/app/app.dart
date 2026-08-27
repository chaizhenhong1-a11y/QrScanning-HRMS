import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../features/employees/presentation/pages/activate_invite_page.dart';
import '../features/identity/application/identity_service.dart';
import '../features/identity/domain/tenant_identity.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import 'navigation/app_routes.dart';
import 'navigation/main_shell.dart';
import 'theme/app_theme.dart';

class QrScanningApp extends StatelessWidget {
  const QrScanningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.root,
      routes: {
        AppRoutes.root: (_) => const AuthGate(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.activateInvite: (_) => const ActivateInvitePage(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static final _identityService = IdentityService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TenantIdentity?>(
      future: _identityService.restoreIdentity(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final identity = snapshot.data;
        if (identity == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            }
          });
          return const SizedBox.shrink();
        }

        return MainShell(
          role: identity.legacyShellRole,
          hrmsRole: identity.role,
        );
      },
    );
  }
}
