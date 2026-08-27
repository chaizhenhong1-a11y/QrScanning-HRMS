import '../../identity/application/identity_service.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/company_policy_repository.dart';
import '../domain/company_policy.dart';

class CompanyPolicySession {
  const CompanyPolicySession({
    required this.companyId,
    required this.uid,
    required this.displayName,
    required this.canManage,
  });

  final String companyId;
  final String uid;
  final String displayName;
  final bool canManage;
}

class CompanyPolicyService {
  CompanyPolicyService({
    CompanyPolicyRepository? repository,
    IdentityService? identityService,
  }) : _repository = repository ?? const CompanyPolicyRepository(),
       _identityService = identityService ?? IdentityService();

  final CompanyPolicyRepository _repository;
  final IdentityService _identityService;

  Future<CompanyPolicySession> session() async {
    final identity = await _identityService.restoreIdentity();
    if (identity == null) {
      throw StateError('Your Veyra HRMS session is unavailable.');
    }

    return CompanyPolicySession(
      companyId: identity.companyId,
      uid: identity.uid,
      displayName: identity.displayName.isEmpty
          ? identity.employeeId
          : identity.displayName,
      canManage:
          identity.role == HrmsRole.companyOwner ||
          identity.role == HrmsRole.hrAdmin,
    );
  }

  Stream<List<CompanyPolicy>> watch(CompanyPolicySession session) {
    return _repository.watch(session.companyId);
  }

  Future<void> create({
    required CompanyPolicySession session,
    required String title,
    required String body,
    required CompanyPolicyCategory category,
  }) async {
    _requireManager(session);
    _validate(title: title, body: body);

    await _repository.create(
      companyId: session.companyId,
      title: title,
      body: body,
      category: category,
      authorUid: session.uid,
      authorName: session.displayName,
    );
  }

  Future<void> update({
    required CompanyPolicySession session,
    required CompanyPolicy policy,
    required String title,
    required String body,
    required CompanyPolicyCategory category,
  }) async {
    _requireManager(session);
    _validate(title: title, body: body);

    await _repository.update(
      companyId: session.companyId,
      policy: policy,
      title: title,
      body: body,
      category: category,
    );
  }

  Future<void> setActive({
    required CompanyPolicySession session,
    required CompanyPolicy policy,
    required bool isActive,
  }) async {
    _requireManager(session);
    await _repository.setActive(
      companyId: session.companyId,
      policy: policy,
      isActive: isActive,
    );
  }

  Future<void> delete({
    required CompanyPolicySession session,
    required CompanyPolicy policy,
  }) async {
    _requireManager(session);
    await _repository.delete(companyId: session.companyId, policyId: policy.id);
  }

  void _requireManager(CompanyPolicySession session) {
    if (!session.canManage) {
      throw StateError(
        'Only Company Owner or HR Admin can manage company policies.',
      );
    }
  }

  void _validate({required String title, required String body}) {
    final cleanTitle = title.trim();
    final cleanBody = body.trim();

    if (cleanTitle.length < 3 || cleanTitle.length > 120) {
      throw ArgumentError(
        'Policy title must contain between 3 and 120 characters.',
      );
    }
    if (cleanBody.length < 10 || cleanBody.length > 10000) {
      throw ArgumentError(
        'Policy content must contain between 10 and 10000 characters.',
      );
    }
  }
}
