import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/employee_lifecycle.dart';

class EmployeeLifecycleRepository {
  EmployeeLifecycleRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseServices.functions;

  final FirebaseFunctions _functions;

  Future<
    ({
      bool canManage,
      String currentEmployeeId,
      List<EmployeeLifecycleCase> cases,
    })
  >
  overview() async {
    final result = await _functions
        .httpsCallable('getEmployeeLifecycleOverview')
        .call<Map<String, dynamic>>();
    final data = Map<String, dynamic>.from(result.data);
    return (
      canManage: data['canManage'] as bool? ?? false,
      currentEmployeeId: data['currentEmployeeId'] as String? ?? '',
      cases: (data['cases'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                EmployeeLifecycleCase.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }

  Future<void> startOnboarding({
    required String employeeId,
    required String startDateKey,
    String? probationEndDateKey,
  }) => _functions.httpsCallable('startEmployeeOnboarding').call<void>({
    'employeeId': employeeId,
    'startDateKey': startDateKey,
    'probationEndDateKey': ?probationEndDateKey,
  });

  Future<void> startOffboarding({
    required String employeeId,
    required String lastWorkingDateKey,
    required String reason,
  }) => _functions.httpsCallable('startEmployeeOffboarding').call<void>({
    'employeeId': employeeId,
    'lastWorkingDateKey': lastWorkingDateKey,
    'reason': reason,
  });

  Future<void> setTaskCompleted({
    required String caseId,
    required String taskId,
    required bool completed,
  }) => _functions.httpsCallable('updateLifecycleTask').call<void>({
    'caseId': caseId,
    'taskId': taskId,
    'completed': completed,
  });

  Future<void> completeCase(String caseId) => _functions
      .httpsCallable('completeEmployeeLifecycle')
      .call<void>({'caseId': caseId});
}
