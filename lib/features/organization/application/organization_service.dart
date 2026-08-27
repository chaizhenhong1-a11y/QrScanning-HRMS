import '../../../core/storage/session_store.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/organization_repository.dart';
import '../domain/branch.dart';
import '../domain/company_profile.dart';
import '../domain/department.dart';

class OrganizationService {
  OrganizationService({OrganizationRepository? repository})
    : _repository = repository ?? OrganizationRepository();

  final OrganizationRepository _repository;

  Future<String> _companyId() async {
    final companyId = await SessionStore.getCompanyId();
    if (companyId == null || companyId.isEmpty) {
      throw StateError('No active company workspace.');
    }
    return companyId;
  }

  Future<void> ensureCanManage() async {
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());
    if (!role.canManageCompany) {
      throw StateError(
        'You do not have permission to manage company settings.',
      );
    }
  }

  Future<CompanyProfile> getCompany() async =>
      _repository.getCompany(await _companyId());

  Future<Stream<List<CompanyBranch>>> branches() async =>
      _repository.watchBranches(await _companyId());

  Future<Stream<List<CompanyDepartment>>> departments() async =>
      _repository.watchDepartments(await _companyId());

  Future<void> updateCompany({
    required String name,
    required String registrationNumber,
    required String timeZone,
  }) async {
    await ensureCanManage();
    await _repository.updateCompany(
      companyId: await _companyId(),
      name: name,
      registrationNumber: registrationNumber,
      timeZone: timeZone,
    );
  }

  Future<void> createBranch({
    required String name,
    required String code,
    required String address,
  }) async {
    await ensureCanManage();
    await _repository.createBranch(
      companyId: await _companyId(),
      name: name,
      code: code,
      address: address,
    );
  }

  Future<void> createDepartment({
    required String name,
    required String code,
  }) async {
    await ensureCanManage();
    await _repository.createDepartment(
      companyId: await _companyId(),
      name: name,
      code: code,
    );
  }

  Future<void> setBranchActive(String branchId, bool isActive) async {
    await ensureCanManage();
    await _repository.setBranchActive(
      companyId: await _companyId(),
      branchId: branchId,
      isActive: isActive,
    );
  }

  Future<void> setDepartmentActive(String departmentId, bool isActive) async {
    await ensureCanManage();
    await _repository.setDepartmentActive(
      companyId: await _companyId(),
      departmentId: departmentId,
      isActive: isActive,
    );
  }
}
