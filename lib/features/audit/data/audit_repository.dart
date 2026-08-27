import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/audit_log_entry.dart';

class AuditRepository {
  AuditRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseServices.functions;

  final FirebaseFunctions _functions;

  Future<List<AuditLogEntry>> load({
    String? module,
    String? action,
    String? actorEmployeeId,
    String? startDateKey,
    String? endDateKey,
  }) async {
    final result = await _functions
        .httpsCallable('getAuditLog')
        .call<Map<String, dynamic>>({
          'module': ?module,
          'action': ?action,
          'actorEmployeeId': ?actorEmployeeId,
          'startDateKey': ?startDateKey,
          'endDateKey': ?endDateKey,
        });

    final data = Map<String, dynamic>.from(result.data);
    return (data['entries'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return AuditLogEntry.fromMap(map['id'] as String? ?? '', map);
        })
        .toList(growable: false);
  }
}
