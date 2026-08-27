import '../../../core/storage/session_store.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/workforce_time_repository.dart';
import '../domain/workforce_time_models.dart';

class WorkforceTimeService {
  WorkforceTimeService({WorkforceTimeRepository? repository})
    : _repository = repository ?? WorkforceTimeRepository();

  final WorkforceTimeRepository _repository;

  Future<HrmsRole> get _role async =>
      HrmsRole.fromValue(await SessionStore.getHrmsRole());

  Future<
    ({
      List<CompanyHoliday> holidays,
      List<EmployeeShift> shifts,
      List<OvertimeRequest> overtime,
    })
  >
  overview(String month) => _repository.overview(month);

  Future<void> saveHoliday({
    required String dateKey,
    required String name,
    required bool isPaid,
  }) async {
    if (!(await _role).canManageCompany) {
      throw StateError('Only Company Owner or HR can manage holidays.');
    }
    await _repository.saveHoliday(dateKey: dateKey, name: name, isPaid: isPaid);
  }

  Future<void> assignShift({
    required String employeeId,
    required String dateKey,
    required String shiftName,
    required int startMinutes,
    required int endMinutes,
  }) async {
    if (!(await _role).canApprove) {
      throw StateError('You do not have permission to assign shifts.');
    }
    await _repository.assignShift(
      employeeId: employeeId,
      dateKey: dateKey,
      shiftName: shiftName,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );
  }

  Future<void> submitOvertime({
    required String dateKey,
    required int minutes,
    required String reason,
  }) => _repository.submitOvertime(
    dateKey: dateKey,
    minutes: minutes,
    reason: reason,
  );

  Future<void> reviewOvertime({
    required String requestId,
    required String decision,
    required String note,
  }) async {
    if (!(await _role).canApprove) {
      throw StateError('You do not have permission to review overtime.');
    }
    await _repository.reviewOvertime(
      requestId: requestId,
      decision: decision,
      note: note,
    );
  }
}
