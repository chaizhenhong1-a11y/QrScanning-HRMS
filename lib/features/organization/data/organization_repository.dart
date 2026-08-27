import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/branch.dart';
import '../domain/company_profile.dart';
import '../domain/department.dart';

class OrganizationRepository {
  OrganizationRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseServices.firestore;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _company(String companyId) =>
      _db.collection('companies').doc(companyId);

  Future<CompanyProfile> getCompany(String companyId) async {
    final snapshot = await _company(companyId).get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Company workspace was not found.');
    }
    return CompanyProfile(
      id: snapshot.id,
      name: (data['name'] as String?) ?? 'Company',
      status: (data['status'] as String?) ?? 'active',
      registrationNumber: (data['registrationNumber'] as String?) ?? '',
      timeZone: (data['timeZone'] as String?) ?? 'Asia/Kuala_Lumpur',
    );
  }

  Stream<List<CompanyBranch>> watchBranches(String companyId) {
    return _company(companyId)
        .collection('branches')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) {
                final data = doc.data();
                return CompanyBranch(
                  id: doc.id,
                  name: (data['name'] as String?) ?? '',
                  code: (data['code'] as String?) ?? '',
                  address: (data['address'] as String?) ?? '',
                  isActive: (data['isActive'] as bool?) ?? true,
                );
              })
              .toList(growable: false),
        );
  }

  Stream<List<CompanyDepartment>> watchDepartments(String companyId) {
    return _company(companyId)
        .collection('departments')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) {
                final data = doc.data();
                return CompanyDepartment(
                  id: doc.id,
                  name: (data['name'] as String?) ?? '',
                  code: (data['code'] as String?) ?? '',
                  isActive: (data['isActive'] as bool?) ?? true,
                );
              })
              .toList(growable: false),
        );
  }

  Future<void> updateCompany({
    required String companyId,
    required String name,
    required String registrationNumber,
    required String timeZone,
  }) async {
    await _company(companyId).update({
      'name': name.trim(),
      'registrationNumber': registrationNumber.trim(),
      'timeZone': timeZone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createBranch({
    required String companyId,
    required String name,
    required String code,
    required String address,
  }) async {
    await _company(companyId).collection('branches').add({
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'address': address.trim(),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createDepartment({
    required String companyId,
    required String name,
    required String code,
  }) async {
    await _company(companyId).collection('departments').add({
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setBranchActive({
    required String companyId,
    required String branchId,
    required bool isActive,
  }) async {
    await _company(companyId).collection('branches').doc(branchId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setDepartmentActive({
    required String companyId,
    required String departmentId,
    required bool isActive,
  }) async {
    await _company(
      companyId,
    ).collection('departments').doc(departmentId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
