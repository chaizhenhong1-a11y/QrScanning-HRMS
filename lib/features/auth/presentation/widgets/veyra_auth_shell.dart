import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';

class VeyraAuthShell extends StatelessWidget {
  const VeyraAuthShell({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Row(
              children: [
                if (wide) const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(
                  flex: wide ? 6 : 1,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 64 : 24,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!wide) ...[
                              const VeyraWordmark(),
                              const SizedBox(height: 38),
                            ],
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: VeyraDesign.ink,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.8,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: VeyraDesign.muted,
                                    height: 1.45,
                                  ),
                            ),
                            const SizedBox(height: 30),
                            child,
                            if (footer != null) ...[
                              const SizedBox(height: 22),
                              footer!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class VeyraWordmark extends StatelessWidget {
  const VeyraWordmark({super.key, this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : VeyraDesign.navy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: light ? Colors.white : VeyraDesign.blue,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: Text(
            'V',
            style: TextStyle(
              color: light ? VeyraDesign.blue : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Veyra',
          style: TextStyle(
            color: color,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: light
                ? Colors.white.withValues(alpha: .14)
                : VeyraDesign.sky,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            'HRMS',
            style: TextStyle(
              color: light ? Colors.white : VeyraDesign.blue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(54),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VeyraDesign.navy, VeyraDesign.blueDark],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VeyraWordmark(light: true),
          Spacer(),
          Text(
            'People operations,\nwithout the friction.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'Attendance, leave, claims, payroll and your workforce — one secure workspace.',
            style: TextStyle(
              color: Color(0xFFD9E2FF),
              fontSize: 17,
              height: 1.55,
            ),
          ),
          SizedBox(height: 42),
          _TrustRow(),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.verified_user_outlined, color: Colors.white70, size: 20),
        SizedBox(width: 9),
        Text(
          'Secure multi-company HR workspace',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class VeyraErrorBanner extends StatelessWidget {
  const VeyraErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: VeyraDesign.danger, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: VeyraDesign.danger, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
