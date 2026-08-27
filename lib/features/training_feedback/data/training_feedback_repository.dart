import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/training_feedback.dart';

class TrainingFeedbackRepository {
  const TrainingFeedbackRepository();

  FirebaseFirestore get _db => FirebaseServices.firestore;

  CollectionReference<Map<String, dynamic>> _collection(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('trainingFeedback');
  }

  Stream<List<TrainingFeedback>> watchMine({
    required String companyId,
    required String uid,
  }) {
    return _collection(
      companyId,
    ).where('uid', isEqualTo: uid).snapshots().map(_mapAndSort);
  }

  Stream<List<TrainingFeedback>> watchCompany(String companyId) {
    return _collection(companyId).snapshots().map(_mapAndSort);
  }

  List<TrainingFeedback> _mapAndSort(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final items = snapshot.docs
        .map((doc) => TrainingFeedback.fromFirestore(doc.id, doc.data()))
        .toList();

    items.sort((a, b) {
      final left = a.submittedAt ?? a.trainingDate;
      final right = b.submittedAt ?? b.trainingDate;
      return right.compareTo(left);
    });

    return items;
  }

  Future<void> submit({
    required String companyId,
    required String uid,
    required String employeeId,
    required String employeeName,
    required String trainingTitle,
    required DateTime trainingDate,
    required int rating,
    required String comment,
  }) {
    return _collection(companyId).add({
      'uid': uid,
      'employeeId': employeeId,
      'employeeName': employeeName.trim(),
      'trainingTitle': trainingTitle.trim(),
      'trainingDate': Timestamp.fromDate(
        DateTime(trainingDate.year, trainingDate.month, trainingDate.day),
      ),
      'rating': rating,
      'comment': comment.trim(),
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }
}
