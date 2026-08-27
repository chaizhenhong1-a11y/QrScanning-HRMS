import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/company_policy.dart';

class CompanyPolicyRepository {
  const CompanyPolicyRepository();

  FirebaseFirestore get _db => FirebaseServices.firestore;

  CollectionReference<Map<String, dynamic>> _collection(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('companyPolicies');
  }

  Stream<List<CompanyPolicy>> watch(String companyId) {
    return _collection(companyId).snapshots().map((snapshot) {
      final policies = snapshot.docs
          .map((doc) => CompanyPolicy.fromFirestore(doc.id, doc.data()))
          .toList(growable: false);

      final sorted = policies.toList(growable: false);
      sorted.sort((a, b) {
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }

        final left = a.updatedAt ?? a.createdAt;
        final right = b.updatedAt ?? b.createdAt;
        if (left == null && right == null) {
          return a.title.compareTo(b.title);
        }
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });

      return sorted;
    });
  }

  Future<void> create({
    required String companyId,
    required String title,
    required String body,
    required CompanyPolicyCategory category,
    required String authorUid,
    required String authorName,
  }) {
    final now = FieldValue.serverTimestamp();

    return _collection(companyId).add({
      'title': title.trim(),
      'body': body.trim(),
      'category': category.name,
      'isActive': true,
      'authorUid': authorUid,
      'authorName': authorName.trim(),
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> update({
    required String companyId,
    required CompanyPolicy policy,
    required String title,
    required String body,
    required CompanyPolicyCategory category,
  }) {
    return _collection(companyId).doc(policy.id).update({
      'title': title.trim(),
      'body': body.trim(),
      'category': category.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setActive({
    required String companyId,
    required CompanyPolicy policy,
    required bool isActive,
  }) {
    return _collection(companyId).doc(policy.id).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete({required String companyId, required String policyId}) {
    return _collection(companyId).doc(policyId).delete();
  }
}
