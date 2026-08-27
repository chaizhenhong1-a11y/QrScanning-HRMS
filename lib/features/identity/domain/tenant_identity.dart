import 'hrms_role.dart';

class TenantIdentity {
  const TenantIdentity({
    required this.uid,
    required this.companyId,
    required this.employeeId,
    required this.email,
    required this.displayName,
    required this.department,
    required this.role,
    required this.isActive,
  });

  final String uid;
  final String companyId;
  final String employeeId;
  final String email;
  final String displayName;
  final String department;
  final HrmsRole role;
  final bool isActive;

  String get legacyShellRole => role.legacyShellRole;
}
