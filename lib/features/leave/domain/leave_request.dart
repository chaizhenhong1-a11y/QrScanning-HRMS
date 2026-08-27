import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaveRequestStatus { pending, approved, rejected, cancelled }

extension LeaveRequestStatusX on LeaveRequestStatus {
  String get label => switch (this) {
    LeaveRequestStatus.pending => 'Pending',
    LeaveRequestStatus.approved => 'Approved',
    LeaveRequestStatus.rejected => 'Rejected',
    LeaveRequestStatus.cancelled => 'Cancelled',
  };

  static LeaveRequestStatus fromStorage(String? value) {
    return LeaveRequestStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => LeaveRequestStatus.pending,
    );
  }
}

enum LeaveDuration {
  fullDay,
  halfDayMorning,
  halfDayAfternoon;

  String get label => switch (this) {
    LeaveDuration.fullDay => 'Full day',
    LeaveDuration.halfDayMorning => 'Half day · Morning',
    LeaveDuration.halfDayAfternoon => 'Half day · Afternoon',
  };

  static LeaveDuration fromStorage(String? value) {
    return LeaveDuration.values.firstWhere(
      (duration) => duration.name == value,
      orElse: () => LeaveDuration.fullDay,
    );
  }
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.startDateKey,
    required this.endDateKey,
    required this.typeId,
    required this.typeName,
    required this.duration,
    required this.daysRequested,
    required this.reason,
    required this.submittedAt,
    required this.status,
    this.attachmentPath,
    this.reviewedAt,
    this.reviewerId,
    this.reviewerName,
    this.reviewNote,
    this.cancelledAt,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String startDateKey;
  final String endDateKey;
  final String typeId;
  final String typeName;
  final LeaveDuration duration;
  final double daysRequested;
  final String reason;
  final DateTime submittedAt;
  final LeaveRequestStatus status;
  final String? attachmentPath;
  final DateTime? reviewedAt;
  final String? reviewerId;
  final String? reviewerName;
  final String? reviewNote;
  final DateTime? cancelledAt;

  bool covers(String dateKey) =>
      status == LeaveRequestStatus.approved &&
      startDateKey.compareTo(dateKey) <= 0 &&
      endDateKey.compareTo(dateKey) >= 0;

  factory LeaveRequest.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? timestamp(String key) => (data[key] as Timestamp?)?.toDate();

    return LeaveRequest(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? 'Employee',
      department: data['department'] as String? ?? '',
      startDateKey: data['startDateKey'] as String? ?? '',
      endDateKey: data['endDateKey'] as String? ?? '',
      typeId: data['typeId'] as String? ?? 'annual',
      typeName: data['typeName'] as String? ?? 'Annual Leave',
      duration: LeaveDuration.fromStorage(data['duration'] as String?),
      daysRequested: (data['daysRequested'] as num?)?.toDouble() ?? 0,
      reason: data['reason'] as String? ?? '',
      submittedAt: timestamp('submittedAt') ?? DateTime.now(),
      status: LeaveRequestStatusX.fromStorage(data['status'] as String?),
      attachmentPath: data['attachmentPath'] as String?,
      reviewedAt: timestamp('reviewedAt'),
      reviewerId: data['reviewerId'] as String?,
      reviewerName: data['reviewerName'] as String?,
      reviewNote: data['reviewNote'] as String?,
      cancelledAt: timestamp('cancelledAt'),
    );
  }
}
