import '../../identity/application/identity_service.dart';
import '../data/training_feedback_repository.dart';
import '../domain/training_feedback.dart';

class TrainingFeedbackSession {
  const TrainingFeedbackSession({
    required this.companyId,
    required this.uid,
    required this.employeeId,
    required this.displayName,
    required this.canReviewCompanyFeedback,
  });

  final String companyId;
  final String uid;
  final String employeeId;
  final String displayName;
  final bool canReviewCompanyFeedback;
}

class TrainingFeedbackService {
  TrainingFeedbackService({
    TrainingFeedbackRepository? repository,
    IdentityService? identityService,
  }) : _repository = repository ?? const TrainingFeedbackRepository(),
       _identityService = identityService ?? IdentityService();

  final TrainingFeedbackRepository _repository;
  final IdentityService _identityService;

  Future<TrainingFeedbackSession> session() async {
    final identity = await _identityService.restoreIdentity();
    if (identity == null) {
      throw StateError('Your Veyra HRMS session is unavailable.');
    }

    return TrainingFeedbackSession(
      companyId: identity.companyId,
      uid: identity.uid,
      employeeId: identity.employeeId,
      displayName: identity.displayName.isEmpty
          ? identity.employeeId
          : identity.displayName,
      canReviewCompanyFeedback: identity.role.canApprove,
    );
  }

  Stream<List<TrainingFeedback>> watchMine(TrainingFeedbackSession session) {
    return _repository.watchMine(
      companyId: session.companyId,
      uid: session.uid,
    );
  }

  Stream<List<TrainingFeedback>> watchCompany(TrainingFeedbackSession session) {
    if (!session.canReviewCompanyFeedback) {
      throw StateError(
        'You do not have permission to review company training feedback.',
      );
    }
    return _repository.watchCompany(session.companyId);
  }

  Future<void> submit({
    required TrainingFeedbackSession session,
    required String trainingTitle,
    required DateTime trainingDate,
    required int rating,
    required String comment,
  }) async {
    final title = trainingTitle.trim();
    final note = comment.trim();
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateOnly = DateTime(
      trainingDate.year,
      trainingDate.month,
      trainingDate.day,
    );

    if (title.length < 3 || title.length > 120) {
      throw ArgumentError(
        'Training title must contain between 3 and 120 characters.',
      );
    }
    if (dateOnly.isAfter(todayOnly)) {
      throw ArgumentError('Training date cannot be in the future.');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5.');
    }
    if (note.length > 2000) {
      throw ArgumentError('Feedback comment cannot exceed 2000 characters.');
    }

    await _repository.submit(
      companyId: session.companyId,
      uid: session.uid,
      employeeId: session.employeeId,
      employeeName: session.displayName,
      trainingTitle: title,
      trainingDate: dateOnly,
      rating: rating,
      comment: note,
    );
  }
}
