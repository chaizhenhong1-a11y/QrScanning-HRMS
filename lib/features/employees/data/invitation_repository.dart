import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_services.dart';
import '../../identity/domain/hrms_role.dart';
import '../../identity/domain/tenant_identity.dart';
import '../domain/employee_invitation.dart';
import '../domain/employee_profile.dart';

class InvitationRepository {
  InvitationRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseServices.functions;

  final FirebaseFunctions _functions;

  Future<EmployeeInvitation> issueInvitation({
    required EmployeeProfile employee,
  }) async {
    final callable = _functions.httpsCallable('issueEmployeeInvitation');
    final response = await callable.call<Map<String, dynamic>>({
      'employeeId': employee.employeeId,
    });

    final data = Map<String, dynamic>.from(response.data);
    final expiresAtRaw = data['expiresAt'] as String?;

    if (data['invitationId'] is! String ||
        data['companyId'] is! String ||
        data['employeeId'] is! String ||
        data['email'] is! String ||
        data['displayName'] is! String ||
        data['role'] is! String ||
        expiresAtRaw == null) {
      throw StateError('Invitation service returned an invalid response.');
    }

    return EmployeeInvitation(
      id: data['invitationId'] as String,
      companyId: data['companyId'] as String,
      employeeId: data['employeeId'] as String,
      email: data['email'] as String,
      displayName: data['displayName'] as String,
      role: HrmsRole.fromValue(data['role'] as String),
      status: 'pending',
      expiresAt: DateTime.parse(expiresAtRaw),
    );
  }

  Future<TenantIdentity> redeemInvitation({
    required String invitationId,
  }) async {
    final callable = _functions.httpsCallable('redeemEmployeeInvitation');
    final response = await callable.call<Map<String, dynamic>>({
      'invitationId': invitationId.trim(),
    });

    final data = Map<String, dynamic>.from(response.data);

    if (data['uid'] is! String ||
        data['companyId'] is! String ||
        data['employeeId'] is! String ||
        data['email'] is! String ||
        data['displayName'] is! String ||
        data['role'] is! String) {
      throw StateError(
        'Account activation service returned an invalid response.',
      );
    }

    return TenantIdentity(
      uid: data['uid'] as String,
      companyId: data['companyId'] as String,
      employeeId: data['employeeId'] as String,
      email: data['email'] as String,
      displayName: data['displayName'] as String,
      department: data['department'] as String? ?? '',
      role: HrmsRole.fromValue(data['role'] as String),
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}
