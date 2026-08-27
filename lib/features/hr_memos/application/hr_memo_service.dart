import '../../identity/application/identity_service.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/hr_memo_repository.dart';
import '../domain/hr_memo.dart';

class HrMemoSession {
  const HrMemoSession({
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

class HrMemoService {
  HrMemoService({
    HrMemoRepository? repository,
    IdentityService? identityService,
  }) : _repository = repository ?? const HrMemoRepository(),
       _identityService = identityService ?? IdentityService();

  final HrMemoRepository _repository;
  final IdentityService _identityService;

  Future<HrMemoSession> session() async {
    final identity = await _identityService.restoreIdentity();
    if (identity == null) {
      throw StateError('Your Veyra HRMS session is unavailable.');
    }

    return HrMemoSession(
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

  Stream<List<HrMemo>> watch(HrMemoSession session) {
    return _repository.watch(session.companyId);
  }

  Future<void> create({
    required HrMemoSession session,
    required String title,
    required String body,
  }) async {
    _requireManager(session);
    _validate(title: title, body: body);

    await _repository.create(
      companyId: session.companyId,
      title: title,
      body: body,
      authorUid: session.uid,
      authorName: session.displayName,
    );
  }

  Future<void> update({
    required HrMemoSession session,
    required HrMemo memo,
    required String title,
    required String body,
  }) async {
    _requireManager(session);
    _validate(title: title, body: body);

    await _repository.update(
      companyId: session.companyId,
      memoId: memo.id,
      title: title,
      body: body,
    );
  }

  Future<void> delete({
    required HrMemoSession session,
    required HrMemo memo,
  }) async {
    _requireManager(session);
    await _repository.delete(companyId: session.companyId, memoId: memo.id);
  }

  void _requireManager(HrMemoSession session) {
    if (!session.canManage) {
      throw StateError('Only Company Owner or HR Admin can manage HR memos.');
    }
  }

  void _validate({required String title, required String body}) {
    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();

    if (normalizedTitle.length < 3) {
      throw ArgumentError('Memo title must contain at least 3 characters.');
    }
    if (normalizedTitle.length > 120) {
      throw ArgumentError('Memo title cannot exceed 120 characters.');
    }
    if (normalizedBody.length < 5) {
      throw ArgumentError('Memo content must contain at least 5 characters.');
    }
    if (normalizedBody.length > 5000) {
      throw ArgumentError('Memo content cannot exceed 5000 characters.');
    }
  }
}
