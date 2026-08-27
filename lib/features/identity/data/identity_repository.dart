import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/hrms_role.dart';
import '../domain/tenant_identity.dart';

class IdentityRepository {
  const IdentityRepository();

  FirebaseFirestore get _db => FirebaseServices.firestore;

  Future<TenantIdentity?> findByUid(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;

    return TenantIdentity(
      uid: uid,
      companyId: (data['companyId'] as String?) ?? '',
      employeeId: (data['employeeId'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      department: (data['department'] as String?) ?? 'Management',
      role: HrmsRole.fromValue(data['role'] as String?),
      isActive: (data['isActive'] as bool?) ?? true,
    );
  }

  Future<TenantIdentity> createCompanyOwner({
    required String uid,
    required String email,
    required String companyName,
    required String employeeId,
    required String displayName,
  }) async {
    final companyRef = _db.collection('companies').doc();
    final userRef = _db.collection('users').doc(uid);
    final employeeRef = companyRef
        .collection('employees')
        .doc(employeeId.trim().toUpperCase());
    final branchRef = companyRef.collection('branches').doc('head-office');
    final departmentRef = companyRef
        .collection('departments')
        .doc('management');
    final now = FieldValue.serverTimestamp();

    final batch = _db.batch();
    batch.set(companyRef, {
      'name': companyName.trim(),
      'status': 'active',
      'createdBy': uid,
      'createdAt': now,
      'timeZone': 'Asia/Kuala_Lumpur',
      'updatedAt': now,
    });
    batch.set(branchRef, {
      'name': 'Head Office',
      'code': 'HQ',
      'address': '',
      'isActive': true,
      'createdAt': now,
      'updatedAt': now,
    });
    batch.set(departmentRef, {
      'name': 'Management',
      'code': 'MGMT',
      'isActive': true,
      'createdAt': now,
      'updatedAt': now,
    });
    batch.set(userRef, {
      'companyId': companyRef.id,
      'employeeId': employeeId.trim().toUpperCase(),
      'email': email.trim().toLowerCase(),
      'displayName': displayName.trim(),
      'department': 'Management',
      'departmentId': departmentRef.id,
      'branch': 'Head Office',
      'branchId': branchRef.id,
      'role': HrmsRole.companyOwner.value,
      'isActive': true,
      'createdAt': now,
      'updatedAt': now,
    });
    batch.set(employeeRef, {
      'uid': uid,
      'employeeId': employeeId.trim().toUpperCase(),
      'email': email.trim().toLowerCase(),
      'displayName': displayName.trim(),
      'department': 'Management',
      'departmentId': departmentRef.id,
      'branch': 'Head Office',
      'branchId': branchRef.id,
      'jobTitle': 'Company Owner',
      'role': HrmsRole.companyOwner.value,
      'employmentStatus': 'active',
      'onboardingStatus': 'active',
      'createdAt': now,
      'updatedAt': now,
    });
    await batch.commit();

    return TenantIdentity(
      uid: uid,
      companyId: companyRef.id,
      employeeId: employeeId.trim().toUpperCase(),
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      department: 'Management',
      role: HrmsRole.companyOwner,
      isActive: true,
    );
  }
}
