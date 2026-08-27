import '../../../core/storage/session_store.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_action_result.dart';
import '../domain/attendance_entry.dart';
import '../domain/attendance_settings.dart';

class AttendanceApplicationService {
  AttendanceApplicationService({AttendanceRepository? repository})
    : _repository = repository ?? AttendanceRepository();

  final AttendanceRepository _repository;

  Future<({String companyId, String employeeId})> _session() async {
    final companyId = await SessionStore.getCompanyId();
    final employeeId = await SessionStore.getUserId();

    if (companyId == null ||
        companyId.isEmpty ||
        employeeId == null ||
        employeeId.isEmpty) {
      throw StateError('No active Veyra HRMS session.');
    }

    return (companyId: companyId, employeeId: employeeId);
  }

  Future<AttendanceActionResult> clockFromApp() =>
      _repository.clock(source: 'app');

  Future<AttendanceActionResult> clockFromQr(String token) =>
      _repository.clock(source: 'qr', qrToken: token);

  Future<String> issueQr() => _repository.issueQr();

  Future<AttendanceSettings> settings() async {
    final session = await _session();
    return _repository.getSettings(session.companyId);
  }

  Future<void> updateSettings(AttendanceSettings settings) =>
      _repository.updateSettings(settings);

  Future<AttendanceEntry?> today() async {
    final session = await _session();
    return _repository.getToday(
      companyId: session.companyId,
      employeeId: session.employeeId,
    );
  }

  Future<List<AttendanceEntry>> history() async {
    final session = await _session();
    return _repository.getEmployeeHistory(
      companyId: session.companyId,
      employeeId: session.employeeId,
    );
  }

  Future<Stream<List<AttendanceEntry>>> teamForDate(String dateKey) async {
    final session = await _session();
    return _repository.watchTeamForDate(
      companyId: session.companyId,
      dateKey: dateKey,
    );
  }
}
