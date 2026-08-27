import '../../../core/storage/session_store.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/payroll_repository.dart';
import '../domain/payroll_models.dart';

class PayrollService {
  PayrollService({PayrollRepository? repository})
    : _repository = repository ?? PayrollRepository();

  final PayrollRepository _repository;

  Future<({String companyId, String employeeId, HrmsRole role})>
  _session() async {
    final companyId = await SessionStore.getCompanyId();
    final employeeId = await SessionStore.getUserId();
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());
    if (companyId == null || employeeId == null) {
      throw StateError('No active Veyra HRMS session.');
    }
    return (companyId: companyId, employeeId: employeeId, role: role);
  }

  Future<List<Payslip>> loadMine() async {
    final session = await _session();
    return _repository.loadMine(
      companyId: session.companyId,
      employeeId: session.employeeId,
    );
  }

  Future<Stream<List<Payslip>>> watchMonth(String month) async {
    final session = await _session();
    if (!session.role.canManageCompany) {
      throw StateError('Only Company Owner or HR can manage payroll.');
    }
    return _repository.watchMonth(companyId: session.companyId, month: month);
  }

  Future<void> setSalaryProfile({
    required String employeeId,
    required double basicSalary,
    required double fixedAllowance,
    required double fixedDeduction,
    required double epfEmployee,
    required double socsoEmployee,
    required double eisEmployee,
  }) async {
    final session = await _session();
    if (!session.role.canManageCompany) {
      throw StateError('Only Company Owner or HR can manage salary profiles.');
    }
    await _repository.setSalaryProfile(
      employeeId: employeeId,
      basicSalary: basicSalary,
      fixedAllowance: fixedAllowance,
      fixedDeduction: fixedDeduction,
      epfEmployee: epfEmployee,
      socsoEmployee: socsoEmployee,
      eisEmployee: eisEmployee,
    );
  }

  Future<void> generateDraft(String month) => _repository.generateDraft(month);
  Future<void> finalize(String month) => _repository.finalize(month);
}
