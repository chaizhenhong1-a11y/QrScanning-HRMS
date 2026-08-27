import 'package:flutter/material.dart';

class IncomeTaxScreen extends StatelessWidget {
  const IncomeTaxScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Income Tax'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Tax calculation & submission (under development)',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
