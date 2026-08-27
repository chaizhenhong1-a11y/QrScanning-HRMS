import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qr_scanning/screens/login_screen.dart';

void main() {
  testWidgets('login screen presents Firebase work-account sign in', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('HRMS Workspace'), findsOneWidget);
    expect(find.text('Sign in to your company account'), findsOneWidget);
    expect(find.text('Work email'), findsOneWidget);
  });
}
