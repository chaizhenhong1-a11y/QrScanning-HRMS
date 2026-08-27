import '../../../core/storage/session_store.dart';
import '../data/notification_repository.dart';
import '../domain/hrms_notification.dart';

class NotificationService {
  NotificationService({NotificationRepository? repository})
    : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;

  Future<({String companyId, String uid})> _session() async {
    final companyId = await SessionStore.getCompanyId();
    final uid = await SessionStore.getFirebaseUid();
    if (companyId == null || uid == null) {
      throw StateError('No active Veyra HRMS session.');
    }
    return (companyId: companyId, uid: uid);
  }

  Future<Stream<List<HrmsNotification>>> watchMine() async {
    final session = await _session();
    return _repository.watch(companyId: session.companyId, uid: session.uid);
  }

  Future<void> markRead(String notificationId) async {
    final session = await _session();
    await _repository.markRead(
      companyId: session.companyId,
      uid: session.uid,
      notificationId: notificationId,
    );
  }

  Future<void> markAllRead() async {
    final session = await _session();
    await _repository.markAllRead(
      companyId: session.companyId,
      uid: session.uid,
    );
  }
}
