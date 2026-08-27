import 'package:cloud_firestore/cloud_firestore.dart';

enum FlexibleWorkType {
  workFromHome('Work From Home'),
  hybrid('Hybrid'),
  flexibleHours('Flexible Hours');

  const FlexibleWorkType(this.label);
  final String label;

  static FlexibleWorkType fromStorage(String? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => FlexibleWorkType.workFromHome,
  );
}

enum FlexibleWorkStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  withdrawn('Withdrawn');

  const FlexibleWorkStatus(this.label);
  final String label;

  static FlexibleWorkStatus fromStorage(String? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => FlexibleWorkStatus.pending,
  );
}

class FlexibleWorkRequest {
  const FlexibleWorkRequest({
    required this.id,
    required this.employeeId,
    required this.uid,
    required this.employeeName,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.startMinutes,
    required this.endMinutes,
    required this.workLocation,
    required this.reason,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewerUid,
    this.reviewerName,
    this.reviewNote,
    this.withdrawnAt,
  });

  final String id;
  final String employeeId;
  final String uid;
  final String employeeName;
  final FlexibleWorkType type;
  final DateTime startDate;
  final DateTime endDate;
  final int startMinutes;
  final int endMinutes;
  final String workLocation;
  final String reason;
  final FlexibleWorkStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewerUid;
  final String? reviewerName;
  final String? reviewNote;
  final DateTime? withdrawnAt;

  factory FlexibleWorkRequest.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime readDate(String key) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    DateTime? optionalDate(String key) => (data[key] as Timestamp?)?.toDate();

    return FlexibleWorkRequest(
      id: id,
      employeeId: data['employeeId'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? 'Employee',
      type: FlexibleWorkType.fromStorage(data['type'] as String?),
      startDate: readDate('startDate'),
      endDate: readDate('endDate'),
      startMinutes: (data['startMinutes'] as num?)?.toInt() ?? 540,
      endMinutes: (data['endMinutes'] as num?)?.toInt() ?? 1080,
      workLocation: data['workLocation'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      status: FlexibleWorkStatus.fromStorage(data['status'] as String?),
      submittedAt: optionalDate('submittedAt'),
      reviewedAt: optionalDate('reviewedAt'),
      reviewerUid: data['reviewerUid'] as String?,
      reviewerName: data['reviewerName'] as String?,
      reviewNote: data['reviewNote'] as String?,
      withdrawnAt: optionalDate('withdrawnAt'),
    );
  }
}
