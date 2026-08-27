enum HrmsRole {
  superAdmin,
  companyOwner,
  hrAdmin,
  manager,
  employee;

  String get value => name;

  bool get canManageCompany => switch (this) {
    HrmsRole.superAdmin || HrmsRole.companyOwner || HrmsRole.hrAdmin => true,
    HrmsRole.manager || HrmsRole.employee => false,
  };

  bool get canApprove => switch (this) {
    HrmsRole.superAdmin ||
    HrmsRole.companyOwner ||
    HrmsRole.hrAdmin ||
    HrmsRole.manager => true,
    HrmsRole.employee => false,
  };

  /// Temporary bridge for screens that still use the original two-role shell.
  String get legacyShellRole => canApprove ? 'boss' : 'employee';

  static HrmsRole fromValue(String? value) {
    return HrmsRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => HrmsRole.employee,
    );
  }
}
