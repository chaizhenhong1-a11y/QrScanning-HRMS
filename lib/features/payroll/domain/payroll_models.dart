import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryProfile {
  const SalaryProfile({
    required this.employeeId,
    required this.basicSalary,
    required this.fixedAllowance,
    required this.fixedDeduction,
    required this.epfEmployee,
    required this.socsoEmployee,
    required this.eisEmployee,
    required this.currency,
  });

  final String employeeId;
  final double basicSalary;
  final double fixedAllowance;
  final double fixedDeduction;
  final double epfEmployee;
  final double socsoEmployee;
  final double eisEmployee;
  final String currency;

  factory SalaryProfile.fromMap(String employeeId, Map<String, dynamic> data) =>
      SalaryProfile(
        employeeId: employeeId,
        basicSalary: (data['basicSalary'] as num?)?.toDouble() ?? 0,
        fixedAllowance: (data['fixedAllowance'] as num?)?.toDouble() ?? 0,
        fixedDeduction: (data['fixedDeduction'] as num?)?.toDouble() ?? 0,
        epfEmployee: (data['epfEmployee'] as num?)?.toDouble() ?? 0,
        socsoEmployee: (data['socsoEmployee'] as num?)?.toDouble() ?? 0,
        eisEmployee: (data['eisEmployee'] as num?)?.toDouble() ?? 0,
        currency: data['currency'] as String? ?? 'MYR',
      );
}

class Payslip {
  const Payslip({
    required this.id,
    required this.month,
    required this.employeeId,
    required this.employeeName,
    required this.basicSalary,
    required this.allowance,
    required this.claimReimbursement,
    required this.unpaidLeaveDeduction,
    required this.otherDeduction,
    required this.epfEmployee,
    required this.socsoEmployee,
    required this.eisEmployee,
    required this.grossPay,
    required this.totalDeduction,
    required this.netPay,
    required this.status,
    this.finalizedAt,
  });

  final String id;
  final String month;
  final String employeeId;
  final String employeeName;
  final double basicSalary;
  final double allowance;
  final double claimReimbursement;
  final double unpaidLeaveDeduction;
  final double otherDeduction;
  final double epfEmployee;
  final double socsoEmployee;
  final double eisEmployee;
  final double grossPay;
  final double totalDeduction;
  final double netPay;
  final String status;
  final DateTime? finalizedAt;

  factory Payslip.fromMap(String id, Map<String, dynamic> data) {
    double money(String key) => (data[key] as num?)?.toDouble() ?? 0;
    return Payslip(
      id: id,
      month: data['month'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? 'Employee',
      basicSalary: money('basicSalary'),
      allowance: money('allowance'),
      claimReimbursement: money('claimReimbursement'),
      unpaidLeaveDeduction: money('unpaidLeaveDeduction'),
      otherDeduction: money('otherDeduction'),
      epfEmployee: money('epfEmployee'),
      socsoEmployee: money('socsoEmployee'),
      eisEmployee: money('eisEmployee'),
      grossPay: money('grossPay'),
      totalDeduction: money('totalDeduction'),
      netPay: money('netPay'),
      status: data['status'] as String? ?? 'draft',
      finalizedAt: (data['finalizedAt'] as Timestamp?)?.toDate(),
    );
  }
}
