import '../../../core/storage/session_store.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/employee_repository.dart';
import '../domain/employee_profile.dart';

class EmployeeService {
  EmployeeService({EmployeeRepository? repository})
    : _repository = repository ?? EmployeeRepository();

  final EmployeeRepository _repository;

  Future<String> companyId() async {
    final companyId = await SessionStore.getCompanyId();
    if (companyId == null || companyId.isEmpty) {
      throw StateError('No active company workspace.');
    }
    return companyId;
  }

  Future<HrmsRole> requireAdmin() async {
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());
    if (!role.canManageCompany) {
      throw StateError('You do not have permission to manage employees.');
    }
    return role;
  }

  Future<Stream<List<EmployeeProfile>>> employees() async =>
      _repository.watchEmployees(await companyId());

  Future<EmployeeProfile> createPendingEmployee({
    required String employeeId,
    required String displayName,
    required String email,
    required HrmsRole role,
    required String jobTitle,
    required String departmentId,
    required String departmentName,
    required String branchId,
    required String branchName,
  }) async {
    await requireAdmin();
    if (role == HrmsRole.superAdmin || role == HrmsRole.companyOwner) {
      throw StateError(
        'Company owner access cannot be assigned from employee onboarding.',
      );
    }

    return _repository.createPendingEmployee(
      companyId: await companyId(),
      employeeId: employeeId,
      displayName: displayName,
      email: email,
      role: role,
      jobTitle: jobTitle,
      departmentId: departmentId,
      departmentName: departmentName,
      branchId: branchId,
      branchName: branchName,
    );
  }

  Future<void> setEmploymentStatus(
    EmployeeProfile employee,
    bool active,
  ) async {
    await requireAdmin();
    if (employee.role == HrmsRole.companyOwner) {
      throw StateError('The company owner cannot be deactivated here.');
    }

    await _repository.setEmploymentStatus(
      companyId: await companyId(),
      employeeId: employee.employeeId,
      isActive: active,
    );
  }
}
