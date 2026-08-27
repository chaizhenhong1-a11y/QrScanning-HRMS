class DashboardSnapshot {
  const DashboardSnapshot({
    required this.userId,
    required this.userName,
    required this.department,
    required this.role,
    required this.workStartLabel,
    required this.workEndLabel,
    required this.clockInTime,
    required this.clockOutTime,
    required this.clockInStatus,
    required this.clockOutStatus,
    required this.monthLoggedDays,
    required this.monthLateCount,
    required this.monthEarlyCount,
    required this.monthNormalCount,
    this.leaveTodayType,
    this.pendingClaimCount = 0,
  });

  final String userId;
  final String userName;
  final String department;
  final String role;
  final String workStartLabel;
  final String workEndLabel;
  final String? clockInTime;
  final String? clockOutTime;
  final String? clockInStatus;
  final String? clockOutStatus;
  final int monthLoggedDays;
  final int monthLateCount;
  final int monthEarlyCount;
  final int monthNormalCount;
  final String? leaveTodayType;
  final int pendingClaimCount;

  bool get hasClockedIn => clockInTime != null;
  bool get hasClockedOut => clockOutTime != null;
  bool get attendanceCompleted => hasClockedIn && hasClockedOut;
  bool get isOnLeaveToday => leaveTodayType != null;

  String get roleLabel => role == 'boss' ? 'Administrator' : 'Employee';

  int get monthExceptionCount => monthLateCount + monthEarlyCount;
}
