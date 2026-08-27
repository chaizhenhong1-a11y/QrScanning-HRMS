import '../../../core/storage/session_store.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/performance_repository.dart';
import '../domain/performance_review.dart';

class PerformanceService {
  PerformanceService({PerformanceRepository? repository})
    : _repository = repository ?? PerformanceRepository();

  final PerformanceRepository _repository;

  Future<
    ({
      bool canManage,
      String currentEmployeeId,
      List<PerformanceReview> reviews,
    })
  >
  overview(String period) => _repository.overview(period);

  Future<void> ensureReview({
    required String period,
    String? employeeId,
  }) async {
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());
    final currentEmployeeId = await SessionStore.getUserId();
    if (employeeId != null &&
        employeeId != currentEmployeeId &&
        !role.canApprove) {
      throw StateError('You cannot create a review for another employee.');
    }
    await _repository.ensureReview(period: period, employeeId: employeeId);
  }

  Future<void> saveGoal({
    required String reviewId,
    String? goalId,
    required String title,
    required String description,
    required double weight,
    required double progress,
  }) => _repository.saveGoal(
    reviewId: reviewId,
    goalId: goalId,
    title: title,
    description: description,
    weight: weight,
    progress: progress,
  );

  Future<void> submitSelfReview({
    required String reviewId,
    required double rating,
    required String comment,
  }) => _repository.submitSelfReview(
    reviewId: reviewId,
    rating: rating,
    comment: comment,
  );

  Future<void> finalizeManagerReview({
    required String reviewId,
    required double rating,
    required String comment,
  }) => _repository.finalizeManagerReview(
    reviewId: reviewId,
    rating: rating,
    comment: comment,
  );
}
