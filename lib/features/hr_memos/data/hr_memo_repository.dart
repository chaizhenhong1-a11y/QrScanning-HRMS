import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/hr_memo.dart';

class HrMemoRepository {
  const HrMemoRepository();

  FirebaseFirestore get _db => FirebaseServices.firestore;

  CollectionReference<Map<String, dynamic>> _collection(String companyId) {
    return _db.collection('companies').doc(companyId).collection('hrMemos');
  }

  Stream<List<HrMemo>> watch(String companyId) {
    return _collection(companyId).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => HrMemo.fromFirestore(doc.id, doc.data()))
          .toList(growable: false);

      items.sort((a, b) {
        final left = a.updatedAt ?? a.createdAt;
        final right = b.updatedAt ?? b.createdAt;
        if (left == null && right == null) return 0;
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });

      return items;
    });
  }

  Future<void> create({
    required String companyId,
    required String title,
    required String body,
    required String authorUid,
    required String authorName,
  }) async {
    final now = FieldValue.serverTimestamp();
    await _collection(companyId).add({
      'title': title.trim(),
      'body': body.trim(),
      'authorUid': authorUid,
      'authorName': authorName.trim(),
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> update({
    required String companyId,
    required String memoId,
    required String title,
    required String body,
  }) async {
    await _collection(companyId).doc(memoId).update({
      'title': title.trim(),
      'body': body.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete({required String companyId, required String memoId}) {
    return _collection(companyId).doc(memoId).delete();
  }
}
