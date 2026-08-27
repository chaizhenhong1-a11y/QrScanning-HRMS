import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyHoliday {
  const CompanyHoliday({
    required this.id,
    required this.dateKey,
    required this.name,
    required this.isPaid,
  });

  final String id;
  final String dateKey;
  final String name;
  final bool isPaid;

  factory CompanyHoliday.fromMap(String id, Map<String, dynamic> data) =>
      CompanyHoliday(
        id: id,
        dateKey: data['dateKey'] as String? ?? '',
        name: data['name'] as String? ?? 'Holiday',
        isPaid: data['isPaid'] as bool? ?? true,
      );
}

class EmployeeShift {
  const EmployeeShift({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.dateKey,
    required this.shiftName,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String dateKey;
  final String shiftName;
  final int startMinutes;
  final int endMinutes;

  String get timeLabel => '${_time(startMinutes)} - ${_time(endMinutes)}';

  static String _time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  factory EmployeeShift.fromMap(String id, Map<String, dynamic> data) =>
      EmployeeShift(
        id: id,
        employeeId: data['employeeId'] as String? ?? '',
        employeeName: data['employeeName'] as String? ?? 'Employee',
        dateKey: data['dateKey'] as String? ?? '',
        shiftName: data['shiftName'] as String? ?? 'Standard',
        startMinutes: (data['startMinutes'] as num?)?.toInt() ?? 540,
        endMinutes: (data['endMinutes'] as num?)?.toInt() ?? 1080,
      );
}

class OvertimeRequest {
  const OvertimeRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.dateKey,
    required this.minutes,
    required this.reason,
    required this.status,
    this.reviewNote,
    this.createdAt,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String dateKey;
  final int minutes;
  final String reason;
  final String status;
  final String? reviewNote;
  final DateTime? createdAt;

  double get hours => minutes / 60;

  factory OvertimeRequest.fromMap(String id, Map<String, dynamic> data) =>
      OvertimeRequest(
        id: id,
        employeeId: data['employeeId'] as String? ?? '',
        employeeName: data['employeeName'] as String? ?? 'Employee',
        dateKey: data['dateKey'] as String? ?? '',
        minutes: (data['minutes'] as num?)?.toInt() ?? 0,
        reason: data['reason'] as String? ?? '',
        status: data['status'] as String? ?? 'pending',
        reviewNote: data['reviewNote'] as String?,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );
}
