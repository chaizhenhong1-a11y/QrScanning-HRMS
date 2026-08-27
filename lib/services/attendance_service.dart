import '../features/attendance/application/attendance_service.dart';
import '../features/attendance/domain/attendance_settings.dart';

class AttendanceRecord {
  const AttendanceRecord({
    required this.type,
    required this.time,
    required this.date,
    this.status = 'Normal',
  });

  final String type;
  final String time;
  final String date;
  final String status;
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.totalRecords,
    required this.lateCount,
    required this.earlyCount,
    required this.normalCount,
  });

  final int totalRecords;
  final int lateCount;
  final int earlyCount;
  final int normalCount;
}

abstract final class AttendanceService {
  static final AttendanceApplicationService _service =
      AttendanceApplicationService();

  static Future<Map<String, int>> getWorkStartTime() async {
    final settings = await _service.settings();
    return {
      'hour': settings.workStartMinutes ~/ 60,
      'minute': settings.workStartMinutes % 60,
    };
  }

  static Future<Map<String, int>> getWorkEndTime() async {
    final settings = await _service.settings();
    return {
      'hour': settings.workEndMinutes ~/ 60,
      'minute': settings.workEndMinutes % 60,
    };
  }

  static Future<void> setWorkStartTime(int hour, int minute) async {
    final settings = await _service.settings();
    await _service.updateSettings(
      AttendanceSettings(
        workStartMinutes: hour * 60 + minute,
        workEndMinutes: settings.workEndMinutes,
        graceMinutes: settings.graceMinutes,
        requireQr: settings.requireQr,
        timeZone: settings.timeZone,
      ),
    );
  }

  static Future<void> setWorkEndTime(int hour, int minute) async {
    final settings = await _service.settings();
    await _service.updateSettings(
      AttendanceSettings(
        workStartMinutes: settings.workStartMinutes,
        workEndMinutes: hour * 60 + minute,
        graceMinutes: settings.graceMinutes,
        requireQr: settings.requireQr,
        timeZone: settings.timeZone,
      ),
    );
  }

  static Future<String?> clockInOut({
    String source = 'app',
    String? qrToken,
  }) async {
    final result = source == 'qr' && qrToken != null
        ? await _service.clockFromQr(qrToken)
        : await _service.clockFromApp();
    return result.message;
  }

  static Future<List<AttendanceRecord>> getRecords({String? userId}) async {
    final entries = await _service.history();
    final records = <AttendanceRecord>[];

    for (final entry in entries) {
      if (entry.clockInAt != null) {
        records.add(
          AttendanceRecord(
            type: 'Clock In',
            time: _formatDateTime(entry.clockInAt!),
            date: entry.dateKey,
            status: entry.clockInStatus == 'late' ? 'Late' : 'Normal',
          ),
        );
      }
      if (entry.clockOutAt != null) {
        records.add(
          AttendanceRecord(
            type: 'Clock Out',
            time: _formatDateTime(entry.clockOutAt!),
            date: entry.dateKey,
            status: entry.clockOutStatus == 'early' ? 'Early' : 'Normal',
          ),
        );
      }
    }

    return records;
  }

  static Future<AttendanceSummary> getSummary({String? userId}) async {
    final records = await getRecords(userId: userId);
    return AttendanceSummary(
      totalRecords: records.length,
      lateCount: records.where((record) => record.status == 'Late').length,
      earlyCount: records.where((record) => record.status == 'Early').length,
      normalCount: records.where((record) => record.status == 'Normal').length,
    );
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
