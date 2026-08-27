import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceEntry {
  const AttendanceEntry({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.dateKey,
    required this.timeZone,
    required this.clockInStatus,
    required this.clockOutStatus,
    required this.source,
    this.department = '',
    this.branch = '',
    this.clockInAt,
    this.clockOutAt,
    this.workedMinutes,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String branch;
  final String dateKey;
  final String timeZone;
  final String clockInStatus;
  final String clockOutStatus;
  final String source;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final int? workedMinutes;

  bool get hasClockedIn => clockInAt != null;
  bool get hasClockedOut => clockOutAt != null;
  bool get isCompleted => hasClockedIn && hasClockedOut;
  bool get isLate => clockInStatus == 'late';
  bool get leftEarly => clockOutStatus == 'early';

  factory AttendanceEntry.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? readDate(String key) => (data[key] as Timestamp?)?.toDate();

    return AttendanceEntry(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? 'Employee',
      department: data['department'] as String? ?? '',
      branch: data['branch'] as String? ?? '',
      dateKey: data['dateKey'] as String? ?? '',
      timeZone: data['timeZone'] as String? ?? 'Asia/Kuala_Lumpur',
      clockInStatus: data['clockInStatus'] as String? ?? '',
      clockOutStatus: data['clockOutStatus'] as String? ?? '',
      source: data['source'] as String? ?? 'app',
      clockInAt: readDate('clockInAt'),
      clockOutAt: readDate('clockOutAt'),
      workedMinutes: (data['workedMinutes'] as num?)?.toInt(),
    );
  }
}
