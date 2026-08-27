import '../../../core/storage/session_store.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/audit_repository.dart';
import '../domain/audit_log_entry.dart';

class AuditService {
  AuditService({AuditRepository? repository})
    : _repository = repository ?? AuditRepository();

  final AuditRepository _repository;

  Future<List<AuditLogEntry>> load({
    String? module,
    String? action,
    String? actorEmployeeId,
    String? startDateKey,
    String? endDateKey,
  }) async {
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());
    if (!role.canManageCompany) {
      throw StateError('Only Company Owner or HR can view company audit logs.');
    }

    return _repository.load(
      module: module,
      action: action,
      actorEmployeeId: actorEmployeeId,
      startDateKey: startDateKey,
      endDateKey: endDateKey,
    );
  }
}
