import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/performance_review.dart';

class PerformanceRepository {
  PerformanceRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseServices.functions;

  final FirebaseFunctions _functions;

  Future<
    ({
      bool canManage,
      String currentEmployeeId,
      List<PerformanceReview> reviews,
    })
  >
  overview(String period) async {
    final result = await _functions
        .httpsCallable('getPerformanceOverview')
        .call<Map<String, dynamic>>({'period': period});
    final data = Map<String, dynamic>.from(result.data);
    final reviews = (data['reviews'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) => PerformanceReview.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    return (
      canManage: data['canManage'] as bool? ?? false,
      currentEmployeeId: data['currentEmployeeId'] as String? ?? '',
      reviews: reviews,
    );
  }

  Future<void> ensureReview({required String period, String? employeeId}) =>
      _functions.httpsCallable('ensurePerformanceReview').call<void>({
        'period': period,
        'employeeId': ?employeeId,
      });

  Future<void> saveGoal({
    required String reviewId,
    String? goalId,
    required String title,
    required String description,
    required double weight,
    required double progress,
  }) => _functions.httpsCallable('upsertPerformanceGoal').call<void>({
    'reviewId': reviewId,
    'goalId': ?goalId,
    'title': title,
    'description': description,
    'weight': weight,
    'progress': progress,
  });

  Future<void> submitSelfReview({
    required String reviewId,
    required double rating,
    required String comment,
  }) => _functions.httpsCallable('submitPerformanceSelfReview').call<void>({
    'reviewId': reviewId,
    'rating': rating,
    'comment': comment,
  });

  Future<void> finalizeManagerReview({
    required String reviewId,
    required double rating,
    required String comment,
  }) => _functions.httpsCallable('finalizePerformanceReview').call<void>({
    'reviewId': reviewId,
    'rating': rating,
    'comment': comment,
  });
}
