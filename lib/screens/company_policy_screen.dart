import 'package:flutter/material.dart';

class CompanyPolicyScreen extends StatelessWidget {
  const CompanyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Policy'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text('1. Working Hours: 9am - 6pm', style: TextStyle(fontSize: 16)),
          SizedBox(height: 10),
          Text('2. Dress Code: Smart casual', style: TextStyle(fontSize: 16)),
          SizedBox(height: 10),
          Text('3. Leave Policy: ...', style: TextStyle(fontSize: 16)),
          // 可扩展为富文本或 PDF 查看
        ],
      ),
    );
  }
}
