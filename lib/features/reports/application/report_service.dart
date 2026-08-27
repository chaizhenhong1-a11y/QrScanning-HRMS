import '../../../core/storage/session_store.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/report_repository.dart';
import '../domain/monthly_hr_report.dart';

class ReportService {
  ReportService({ReportRepository? repository})
    : _repository = repository ?? ReportRepository();

  final ReportRepository _repository;

  Future<MonthlyHrReport> loadMonthly(String month) async {
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());
    if (!role.canApprove) {
      throw StateError('You do not have permission to view HR reports.');
    }
    return _repository.loadMonthly(month);
  }
}
