import 'package:cloud_firestore/cloud_firestore.dart';

enum HrmsNotificationType {
  leaveSubmitted,
  leaveApproved,
  leaveRejected,
  claimSubmitted,
  claimApproved,
  claimRejected,
  claimPaid,
  payslipPublished,
  employeeInvitation,
  general;

  static HrmsNotificationType fromValue(String? value) =>
      HrmsNotificationType.values.firstWhere(
        (item) => item.name == value,
        orElse: () => HrmsNotificationType.general,
      );
}

class HrmsNotification {
  const HrmsNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.targetType,
    this.targetId,
  });

  final String id;
  final HrmsNotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;
  final String? targetType;
  final String? targetId;

  factory HrmsNotification.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) => HrmsNotification(
    id: id,
    type: HrmsNotificationType.fromValue(data['type'] as String?),
    title: data['title'] as String? ?? 'Veyra HRMS',
    body: data['body'] as String? ?? '',
    isRead: data['isRead'] as bool? ?? false,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    targetType: data['targetType'] as String?,
    targetId: data['targetId'] as String?,
  );
}
