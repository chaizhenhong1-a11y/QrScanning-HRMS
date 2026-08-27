import 'package:flutter/material.dart';

abstract final class VeyraDesign {
  // Canonical palette taken directly from the existing Veyra login screen.
  static const ink = Color(0xFF2C3E50);
  static const primary = Color(0xFF4FACFE);
  static const accent = Color(0xFF00F2FE);
  static const pageTop = Color(0xFFF3F6FA);
  static const pageBottom = Color(0xFFE3EDF7);
  static const field = Color(0xFFF8FAFC);
  static const muted = Color(0xFF7A8797);
  static const border = Color(0xFFE3E8EF);
  static const danger = Color(0xFFEF5350);
  static const success = Color(0xFF16A085);
  static const warning = Color(0xFFF59E0B);
  static const surfaceColor = Colors.white;
  static const softBrand = Color(0xFFEAF7FF);
  static const divider = Color(0xFFEDF1F5);

  // Compatibility aliases used by the existing Veyra auth shell.
  // These intentionally map back to the canonical palette above so
  // Login/Register and the signed-in app share one design system.
  static const navy = ink;
  static const blue = primary;
  static const sky = accent;
  static const blueDark = Color(0xFF2F80ED);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );

  static const pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pageTop, pageBottom],
  );

  static BoxDecoration get pageBackground =>
      const BoxDecoration(gradient: pageGradient);

  static BoxDecoration surface({double radius = 24}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .04),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ],
  );
}
