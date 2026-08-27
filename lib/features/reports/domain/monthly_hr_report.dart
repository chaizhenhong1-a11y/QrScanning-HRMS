class MonthlyHrReport {
  const MonthlyHrReport({
    required this.month,
    required this.activeEmployees,
    required this.attendanceRecords,
    required this.presentEmployees,
    required this.lateRecords,
    required this.earlyLeaveRecords,
    required this.completedAttendanceRecords,
    required this.approvedLeaveRequests,
    required this.approvedLeaveDays,
    required this.pendingLeaveRequests,
    required this.claimCount,
    required this.pendingClaimCount,
    required this.approvedClaimCount,
    required this.paidClaimCount,
    required this.claimAmount,
    required this.payrollVisible,
    required this.payrollStatus,
    required this.payrollEmployeeCount,
    required this.totalNetPay,
  });

  final String month;
  final int activeEmployees;
  final int attendanceRecords;
  final int presentEmployees;
  final int lateRecords;
  final int earlyLeaveRecords;
  final int completedAttendanceRecords;
  final int approvedLeaveRequests;
  final double approvedLeaveDays;
  final int pendingLeaveRequests;
  final int claimCount;
  final int pendingClaimCount;
  final int approvedClaimCount;
  final int paidClaimCount;
  final double claimAmount;
  final bool payrollVisible;
  final String? payrollStatus;
  final int payrollEmployeeCount;
  final double totalNetPay;

  double get attendanceCompletionRate => attendanceRecords == 0
      ? 0
      : completedAttendanceRecords / attendanceRecords;

  factory MonthlyHrReport.fromMap(Map<String, dynamic> data) {
    int integer(String key) => (data[key] as num?)?.toInt() ?? 0;
    double number(String key) => (data[key] as num?)?.toDouble() ?? 0;

    return MonthlyHrReport(
      month: data['month'] as String? ?? '',
      activeEmployees: integer('activeEmployees'),
      attendanceRecords: integer('attendanceRecords'),
      presentEmployees: integer('presentEmployees'),
      lateRecords: integer('lateRecords'),
      earlyLeaveRecords: integer('earlyLeaveRecords'),
      completedAttendanceRecords: integer('completedAttendanceRecords'),
      approvedLeaveRequests: integer('approvedLeaveRequests'),
      approvedLeaveDays: number('approvedLeaveDays'),
      pendingLeaveRequests: integer('pendingLeaveRequests'),
      claimCount: integer('claimCount'),
      pendingClaimCount: integer('pendingClaimCount'),
      approvedClaimCount: integer('approvedClaimCount'),
      paidClaimCount: integer('paidClaimCount'),
      claimAmount: number('claimAmount'),
      payrollVisible: data['payrollVisible'] as bool? ?? false,
      payrollStatus: data['payrollStatus'] as String?,
      payrollEmployeeCount: integer('payrollEmployeeCount'),
      totalNetPay: number('totalNetPay'),
    );
  }
}
