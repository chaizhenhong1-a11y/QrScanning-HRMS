class AttendanceSettings {
  const AttendanceSettings({
    required this.workStartMinutes,
    required this.workEndMinutes,
    required this.graceMinutes,
    required this.requireQr,
    required this.timeZone,
  });

  final int workStartMinutes;
  final int workEndMinutes;
  final int graceMinutes;
  final bool requireQr;
  final String timeZone;

  static const defaults = AttendanceSettings(
    workStartMinutes: 9 * 60,
    workEndMinutes: 18 * 60,
    graceMinutes: 5,
    requireQr: false,
    timeZone: 'Asia/Kuala_Lumpur',
  );

  String get workStartLabel => _label(workStartMinutes);
  String get workEndLabel => _label(workEndMinutes);

  static String _label(int totalMinutes) {
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelve:${minute.toString().padLeft(2, '0')} $period';
  }
}
