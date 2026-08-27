import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_services.dart';
import '../../identity/domain/hrms_role.dart';
import '../domain/employee_profile.dart';

class EmployeeRepository {
  EmployeeRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseServices.firestore;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _employees(String companyId) =>
      _db.collection('companies').doc(companyId).collection('employees');

  Stream<List<EmployeeProfile>> watchEmployees(String companyId) {
    return _employees(companyId)
        .orderBy('displayName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_fromDocument).toList(growable: false),
        );
  }

  Future<EmployeeProfile> createPendingEmployee({
    required String companyId,
    required String employeeId,
    required String displayName,
    required String email,
    required HrmsRole role,
    required String jobTitle,
    required String departmentId,
    required String departmentName,
    required String branchId,
    required String branchName,
  }) async {
    final normalizedId = employeeId.trim().toUpperCase();
    final normalizedEmail = email.trim().toLowerCase();
    final ref = _employees(companyId).doc(normalizedId);

    if ((await ref.get()).exists) {
      throw StateError('Employee ID $normalizedId already exists.');
    }

    final profile = EmployeeProfile(
      employeeId: normalizedId,
      displayName: displayName.trim(),
      email: normalizedEmail,
      role: role,
      employmentStatus: 'active',
      onboardingStatus: 'pendingInvite',
      jobTitle: jobTitle.trim(),
      departmentId: departmentId,
      departmentName: departmentName,
      branchId: branchId,
      branchName: branchName,
    );

    await ref.set({
      'employeeId': profile.employeeId,
      'displayName': profile.displayName,
      'email': profile.email,
      'role': profile.role.value,
      'jobTitle': profile.jobTitle,
      'departmentId': profile.departmentId,
      'department': profile.departmentName,
      'branchId': profile.branchId,
      'branch': profile.branchName,
      'employmentStatus': profile.employmentStatus,
      'onboardingStatus': profile.onboardingStatus,
      'uid': null,
      'invitationId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return profile;
  }

  Future<void> setEmploymentStatus({
    required String companyId,
    required String employeeId,
    required bool isActive,
  }) async {
    await _employees(companyId).doc(employeeId).update({
      'employmentStatus': isActive ? 'active' : 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  EmployeeProfile _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return EmployeeProfile(
      employeeId: (data['employeeId'] as String?) ?? doc.id,
      displayName: (data['displayName'] as String?) ?? 'Employee',
      email: (data['email'] as String?) ?? '',
      role: HrmsRole.fromValue(data['role'] as String?),
      employmentStatus: (data['employmentStatus'] as String?) ?? 'active',
      onboardingStatus:
          (data['onboardingStatus'] as String?) ??
          ((data['uid'] as String?)?.isNotEmpty == true
              ? 'active'
              : 'pendingInvite'),
      uid: data['uid'] as String?,
      invitationId: data['invitationId'] as String?,
      jobTitle: (data['jobTitle'] as String?) ?? '',
      departmentId: (data['departmentId'] as String?) ?? '',
      departmentName: (data['department'] as String?) ?? '',
      branchId: (data['branchId'] as String?) ?? '',
      branchName: (data['branch'] as String?) ?? '',
    );
  }
}
