import 'package:flutter/material.dart';
import '../services/memo_service.dart';

class HrMemosScreen extends StatelessWidget {
  const HrMemosScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final memos = MemoService.getMemos();
    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Memos'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: memos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            title: Text(
              memos[i]['title']!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${memos[i]['date']}\n${memos[i]['content']}'),
          ),
        ),
      ),
    );
  }
}
