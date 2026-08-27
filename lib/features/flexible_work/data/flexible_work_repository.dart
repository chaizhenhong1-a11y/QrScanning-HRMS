import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/flexible_work_request.dart';

class FlexibleWorkRepository {
  const FlexibleWorkRepository();

  FirebaseFirestore get _db => FirebaseServices.firestore;

  CollectionReference<Map<String, dynamic>> _requests(String companyId) => _db
      .collection('companies')
      .doc(companyId)
      .collection('flexibleWorkRequests');

  Stream<List<FlexibleWorkRequest>> watchMine({
    required String companyId,
    required String uid,
  }) {
    return _requests(
      companyId,
    ).where('uid', isEqualTo: uid).snapshots().map(_mapAndSort);
  }

  Stream<List<FlexibleWorkRequest>> watchForApproval(String companyId) {
    return _requests(companyId).snapshots().map(_mapAndSort);
  }

  Stream<List<FlexibleWorkRequest>> watchApprovalHistory({
    required String companyId,
    required String reviewerUid,
  }) {
    return _requests(
      companyId,
    ).where('reviewerUid', isEqualTo: reviewerUid).snapshots().map(_mapAndSort);
  }

  List<FlexibleWorkRequest> _mapAndSort(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final items = snapshot.docs
        .map((doc) => FlexibleWorkRequest.fromFirestore(doc.id, doc.data()))
        .toList();

    items.sort((a, b) {
      final left = a.submittedAt ?? a.startDate;
      final right = b.submittedAt ?? b.startDate;
      return right.compareTo(left);
    });

    return items;
  }

  Future<void> create({
    required String companyId,
    required String employeeId,
    required String uid,
    required String employeeName,
    required FlexibleWorkType type,
    required DateTime startDate,
    required DateTime endDate,
    required int startMinutes,
    required int endMinutes,
    required String workLocation,
    required String reason,
  }) => _requests(companyId).add({
    'employeeId': employeeId,
    'uid': uid,
    'employeeName': employeeName,
    'type': type.name,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
    'workLocation': workLocation.trim(),
    'reason': reason.trim(),
    'status': FlexibleWorkStatus.pending.name,
    'submittedAt': FieldValue.serverTimestamp(),
    'reviewedAt': null,
    'reviewerUid': null,
    'reviewerName': null,
    'reviewNote': null,
    'withdrawnAt': null,
  });

  Future<void> withdraw({
    required String companyId,
    required String requestId,
  }) => _requests(companyId).doc(requestId).update({
    'status': FlexibleWorkStatus.withdrawn.name,
    'withdrawnAt': FieldValue.serverTimestamp(),
  });

  Future<void> review({
    required String companyId,
    required String requestId,
    required FlexibleWorkStatus status,
    required String reviewerUid,
    required String reviewerName,
    required String note,
  }) => _requests(companyId).doc(requestId).update({
    'status': status.name,
    'reviewedAt': FieldValue.serverTimestamp(),
    'reviewerUid': reviewerUid,
    'reviewerName': reviewerName,
    'reviewNote': note.trim().isEmpty ? null : note.trim(),
  });
}
