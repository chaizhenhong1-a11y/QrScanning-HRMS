import '../../identity/application/identity_service.dart';
import '../data/flexible_work_repository.dart';
import '../domain/flexible_work_request.dart';

class FlexibleWorkSession {
  const FlexibleWorkSession({
    required this.companyId,
    required this.uid,
    required this.employeeId,
    required this.displayName,
    required this.canApprove,
  });

  final String companyId;
  final String uid;
  final String employeeId;
  final String displayName;
  final bool canApprove;
}

class FlexibleWorkService {
  FlexibleWorkService({
    FlexibleWorkRepository? repository,
    IdentityService? identityService,
  }) : _repository = repository ?? const FlexibleWorkRepository(),
       _identityService = identityService ?? IdentityService();

  final FlexibleWorkRepository _repository;
  final IdentityService _identityService;

  Future<FlexibleWorkSession> session() async {
    final identity = await _identityService.restoreIdentity();
    if (identity == null) {
      throw StateError('Your Veyra HRMS session is unavailable.');
    }
    return FlexibleWorkSession(
      companyId: identity.companyId,
      uid: identity.uid,
      employeeId: identity.employeeId,
      displayName: identity.displayName.isEmpty
          ? identity.employeeId
          : identity.displayName,
      canApprove: identity.role.canApprove,
    );
  }

  Stream<List<FlexibleWorkRequest>> watchMine(FlexibleWorkSession session) {
    return _repository.watchMine(
      companyId: session.companyId,
      uid: session.uid,
    );
  }

  Stream<List<FlexibleWorkRequest>> watchForApproval(
    FlexibleWorkSession session,
  ) {
    if (!session.canApprove) {
      throw StateError(
        'You do not have permission to review flexible work requests.',
      );
    }
    return _repository.watchForApproval(session.companyId);
  }

  Stream<List<FlexibleWorkRequest>> watchApprovalHistory(
    FlexibleWorkSession session,
  ) {
    if (!session.canApprove) {
      throw StateError(
        'You do not have permission to review flexible work requests.',
      );
    }
    return _repository.watchApprovalHistory(
      companyId: session.companyId,
      reviewerUid: session.uid,
    );
  }

  Future<void> submit({
    required FlexibleWorkSession session,
    required FlexibleWorkType type,
    required DateTime startDate,
    required DateTime endDate,
    required int startMinutes,
    required int endMinutes,
    required String workLocation,
    required String reason,
  }) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    if (start.isBefore(todayOnly)) {
      throw ArgumentError('Start date cannot be in the past.');
    }
    if (end.isBefore(start)) {
      throw ArgumentError('End date cannot be before start date.');
    }
    if (end.difference(start).inDays > 90) {
      throw ArgumentError('A flexible work request cannot exceed 90 days.');
    }
    if (startMinutes < 0 ||
        startMinutes >= 1440 ||
        endMinutes <= startMinutes ||
        endMinutes > 1440) {
      throw ArgumentError('Choose a valid start and end time.');
    }
    if (reason.trim().length < 5 || reason.trim().length > 1000) {
      throw ArgumentError('Reason must contain between 5 and 1000 characters.');
    }
    if (workLocation.trim().length > 160) {
      throw ArgumentError('Work location cannot exceed 160 characters.');
    }

    await _repository.create(
      companyId: session.companyId,
      employeeId: session.employeeId,
      uid: session.uid,
      employeeName: session.displayName,
      type: type,
      startDate: start,
      endDate: end,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      workLocation: workLocation,
      reason: reason,
    );
  }

  Future<void> withdraw({
    required FlexibleWorkSession session,
    required FlexibleWorkRequest request,
  }) async {
    if (request.uid != session.uid ||
        request.status != FlexibleWorkStatus.pending) {
      throw StateError('Only your own pending request can be withdrawn.');
    }
    await _repository.withdraw(
      companyId: session.companyId,
      requestId: request.id,
    );
  }

  Future<void> review({
    required FlexibleWorkSession session,
    required FlexibleWorkRequest request,
    required FlexibleWorkStatus status,
    required String note,
  }) async {
    if (!session.canApprove) {
      throw StateError(
        'You do not have permission to review flexible work requests.',
      );
    }
    if (request.uid == session.uid ||
        request.employeeId == session.employeeId) {
      throw StateError('You cannot review your own flexible work request.');
    }
    if (request.status != FlexibleWorkStatus.pending) {
      throw StateError('Only pending requests can be reviewed.');
    }
    if (status != FlexibleWorkStatus.approved &&
        status != FlexibleWorkStatus.rejected) {
      throw ArgumentError('Review status must be approved or rejected.');
    }
    await _repository.review(
      companyId: session.companyId,
      requestId: request.id,
      status: status,
      reviewerUid: session.uid,
      reviewerName: session.displayName,
      note: note,
    );
  }
}
