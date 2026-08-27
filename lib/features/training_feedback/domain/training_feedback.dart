import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingFeedback {
  const TrainingFeedback({
    required this.id,
    required this.uid,
    required this.employeeId,
    required this.employeeName,
    required this.trainingTitle,
    required this.trainingDate,
    required this.rating,
    required this.comment,
    required this.submittedAt,
  });

  final String id;
  final String uid;
  final String employeeId;
  final String employeeName;
  final String trainingTitle;
  final DateTime trainingDate;
  final int rating;
  final String comment;
  final DateTime? submittedAt;

  factory TrainingFeedback.fromFirestore(String id, Map<String, dynamic> data) {
    return TrainingFeedback(
      id: id,
      uid: data['uid'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? 'Employee',
      trainingTitle: data['trainingTitle'] as String? ?? 'Training',
      trainingDate:
          (data['trainingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rating: (data['rating'] as num?)?.toInt() ?? 3,
      comment: data['comment'] as String? ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
    );
  }
}
