import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/monthly_hr_report.dart';

class ReportRepository {
  ReportRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseServices.functions;

  final FirebaseFunctions _functions;

  Future<MonthlyHrReport> loadMonthly(String month) async {
    final result = await _functions
        .httpsCallable('getMonthlyHrReport')
        .call<Map<String, dynamic>>({'month': month});
    return MonthlyHrReport.fromMap(Map<String, dynamic>.from(result.data));
  }
}
