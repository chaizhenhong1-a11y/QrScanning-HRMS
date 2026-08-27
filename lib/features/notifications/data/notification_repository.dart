import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/hrms_notification.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseServices.firestore;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _notifications(
    String companyId,
    String uid,
  ) => _db
      .collection('companies')
      .doc(companyId)
      .collection('userNotifications')
      .doc(uid)
      .collection('items');

  Stream<List<HrmsNotification>> watch({
    required String companyId,
    required String uid,
  }) => _notifications(companyId, uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => HrmsNotification.fromFirestore(doc.id, doc.data()))
            .toList(growable: false),
      );

  Future<void> markRead({
    required String companyId,
    required String uid,
    required String notificationId,
  }) => _notifications(companyId, uid).doc(notificationId).update({
    'isRead': true,
    'readAt': FieldValue.serverTimestamp(),
  });

  Future<void> markAllRead({
    required String companyId,
    required String uid,
  }) async {
    final unread = await _notifications(
      companyId,
      uid,
    ).where('isRead', isEqualTo: false).limit(100).get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
