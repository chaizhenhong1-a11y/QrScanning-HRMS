import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/payroll_models.dart';

class PayrollRepository {
  PayrollRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseServices.firestore,
       _functions = functions ?? FirebaseServices.functions;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Future<List<Payslip>> loadMine({
    required String companyId,
    required String employeeId,
  }) async {
    final snapshot = await _db
        .collection('companies')
        .doc(companyId)
        .collection('payslips')
        .where('employeeId', isEqualTo: employeeId)
        .get();
    final items =
        snapshot.docs.map((doc) => Payslip.fromMap(doc.id, doc.data())).toList()
          ..sort((a, b) => b.month.compareTo(a.month));
    return List.unmodifiable(items);
  }

  Stream<List<Payslip>> watchMonth({
    required String companyId,
    required String month,
  }) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('payslips')
        .where('month', isEqualTo: month)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => Payslip.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
          return List.unmodifiable(items);
        });
  }

  Future<void> setSalaryProfile({
    required String employeeId,
    required double basicSalary,
    required double fixedAllowance,
    required double fixedDeduction,
    required double epfEmployee,
    required double socsoEmployee,
    required double eisEmployee,
  }) async {
    await _functions.httpsCallable('setSalaryProfile').call<void>({
      'employeeId': employeeId,
      'basicSalary': basicSalary,
      'fixedAllowance': fixedAllowance,
      'fixedDeduction': fixedDeduction,
      'epfEmployee': epfEmployee,
      'socsoEmployee': socsoEmployee,
      'eisEmployee': eisEmployee,
      'currency': 'MYR',
    });
  }

  Future<void> generateDraft(String month) => _functions
      .httpsCallable('generatePayrollDraft')
      .call<void>({'month': month});

  Future<void> finalize(String month) =>
      _functions.httpsCallable('finalizePayroll').call<void>({'month': month});
}
