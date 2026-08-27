import '../data/employee_lifecycle_repository.dart';
import '../domain/employee_lifecycle.dart';

class EmployeeLifecycleService {
  EmployeeLifecycleService({EmployeeLifecycleRepository? repository})
    : _repository = repository ?? EmployeeLifecycleRepository();

  final EmployeeLifecycleRepository _repository;

  Future<
    ({
      bool canManage,
      String currentEmployeeId,
      List<EmployeeLifecycleCase> cases,
    })
  >
  overview() => _repository.overview();

  Future<void> startOnboarding({
    required String employeeId,
    required String startDateKey,
    String? probationEndDateKey,
  }) => _repository.startOnboarding(
    employeeId: employeeId,
    startDateKey: startDateKey,
    probationEndDateKey: probationEndDateKey,
  );

  Future<void> startOffboarding({
    required String employeeId,
    required String lastWorkingDateKey,
    required String reason,
  }) => _repository.startOffboarding(
    employeeId: employeeId,
    lastWorkingDateKey: lastWorkingDateKey,
    reason: reason,
  );

  Future<void> setTaskCompleted({
    required String caseId,
    required String taskId,
    required bool completed,
  }) => _repository.setTaskCompleted(
    caseId: caseId,
    taskId: taskId,
    completed: completed,
  );

  Future<void> completeCase(String caseId) => _repository.completeCase(caseId);
}
