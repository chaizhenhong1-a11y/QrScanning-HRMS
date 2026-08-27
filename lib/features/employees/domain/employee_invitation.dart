import '../../identity/domain/hrms_role.dart';

class EmployeeInvitation {
  const EmployeeInvitation({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    required this.expiresAt,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final String email;
  final String displayName;
  final HrmsRole role;
  final String status;
  final DateTime expiresAt;

  bool get isPending => status == 'pending';
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
