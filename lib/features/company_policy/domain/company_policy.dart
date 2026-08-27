import 'package:cloud_firestore/cloud_firestore.dart';

enum CompanyPolicyCategory {
  attendance('Attendance'),
  leave('Leave'),
  dressCode('Dress Code'),
  flexibleWork('Flexible Work'),
  benefits('Benefits'),
  conduct('Code of Conduct'),
  general('General');

  const CompanyPolicyCategory(this.label);

  final String label;

  static CompanyPolicyCategory fromStorage(String? value) {
    return CompanyPolicyCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => CompanyPolicyCategory.general,
    );
  }
}

class CompanyPolicy {
  const CompanyPolicy({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.isActive,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final CompanyPolicyCategory category;
  final bool isActive;
  final String authorUid;
  final String authorName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CompanyPolicy.fromFirestore(String id, Map<String, dynamic> data) {
    return CompanyPolicy(
      id: id,
      title: (data['title'] as String? ?? '').trim(),
      body: (data['body'] as String? ?? '').trim(),
      category: CompanyPolicyCategory.fromStorage(data['category'] as String?),
      isActive: data['isActive'] as bool? ?? true,
      authorUid: (data['authorUid'] as String? ?? '').trim(),
      authorName: (data['authorName'] as String? ?? '').trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
