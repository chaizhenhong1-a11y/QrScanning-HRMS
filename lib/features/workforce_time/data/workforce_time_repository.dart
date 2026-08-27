import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/workforce_time_models.dart';

class WorkforceTimeRepository {
  WorkforceTimeRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseServices.functions;

  final FirebaseFunctions _functions;

  Future<
    ({
      List<CompanyHoliday> holidays,
      List<EmployeeShift> shifts,
      List<OvertimeRequest> overtime,
    })
  >
  overview(String month) async {
    final result = await _functions
        .httpsCallable('getWorkforceTimeOverview')
        .call<Map<String, dynamic>>({'month': month});
    final data = Map<String, dynamic>.from(result.data);
    List<Map<String, dynamic>> maps(String key) =>
        (data[key] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);

    return (
      holidays: maps('holidays')
          .map((item) => CompanyHoliday.fromMap(item['id'] as String, item))
          .toList(growable: false),
      shifts: maps('shifts')
          .map((item) => EmployeeShift.fromMap(item['id'] as String, item))
          .toList(growable: false),
      overtime: maps('overtime')
          .map((item) => OvertimeRequest.fromMap(item['id'] as String, item))
          .toList(growable: false),
    );
  }

  Future<void> saveHoliday({
    required String dateKey,
    required String name,
    required bool isPaid,
  }) => _functions.httpsCallable('upsertCompanyHoliday').call<void>({
    'dateKey': dateKey,
    'name': name,
    'isPaid': isPaid,
  });

  Future<void> assignShift({
    required String employeeId,
    required String dateKey,
    required String shiftName,
    required int startMinutes,
    required int endMinutes,
  }) => _functions.httpsCallable('assignEmployeeShift').call<void>({
    'employeeId': employeeId,
    'dateKey': dateKey,
    'shiftName': shiftName,
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
  });

  Future<void> submitOvertime({
    required String dateKey,
    required int minutes,
    required String reason,
  }) => _functions.httpsCallable('submitOvertimeRequest').call<void>({
    'dateKey': dateKey,
    'minutes': minutes,
    'reason': reason,
  });

  Future<void> reviewOvertime({
    required String requestId,
    required String decision,
    required String note,
  }) => _functions.httpsCallable('reviewOvertimeRequest').call<void>({
    'requestId': requestId,
    'decision': decision,
    'note': note,
  });
}
