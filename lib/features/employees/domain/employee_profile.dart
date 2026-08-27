import '../../identity/domain/hrms_role.dart';

class EmployeeProfile {
  const EmployeeProfile({
    required this.employeeId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.employmentStatus,
    required this.onboardingStatus,
    this.uid,
    this.invitationId,
    this.jobTitle = '',
    this.departmentId = '',
    this.departmentName = '',
    this.branchId = '',
    this.branchName = '',
  });

  final String employeeId;
  final String displayName;
  final String email;
  final HrmsRole role;
  final String employmentStatus;
  final String onboardingStatus;
  final String? uid;
  final String? invitationId;
  final String jobTitle;
  final String departmentId;
  final String departmentName;
  final String branchId;
  final String branchName;

  bool get isActive => employmentStatus == 'active';
  bool get hasAccount => uid != null && uid!.isNotEmpty;
  bool get hasPendingInvitation =>
      !hasAccount &&
      invitationId != null &&
      invitationId!.isNotEmpty &&
      onboardingStatus == 'invited';
}
