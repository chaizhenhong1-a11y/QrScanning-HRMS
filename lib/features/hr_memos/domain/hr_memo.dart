import 'package:cloud_firestore/cloud_firestore.dart';

class HrMemo {
  const HrMemo({
    required this.id,
    required this.title,
    required this.body,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final String authorUid;
  final String authorName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory HrMemo.fromFirestore(String id, Map<String, dynamic> data) {
    return HrMemo(
      id: id,
      title: (data['title'] as String? ?? '').trim(),
      body: (data['body'] as String? ?? '').trim(),
      authorUid: (data['authorUid'] as String? ?? '').trim(),
      authorName: (data['authorName'] as String? ?? '').trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
