class AttendanceActionResult {
  const AttendanceActionResult({
    required this.action,
    required this.dateKey,
    required this.status,
    required this.message,
  });

  final String action;
  final String dateKey;
  final String status;
  final String message;
}
