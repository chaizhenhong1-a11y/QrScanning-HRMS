import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/leave_balance.dart';
import '../domain/leave_policy.dart';
import '../domain/leave_request.dart';

class LeaveRepository {
  LeaveRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  }) : _db = firestore ?? FirebaseServices.firestore,
       _functions = functions ?? FirebaseServices.functions,
       _storage = storage ?? FirebaseServices.storage;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _requests(String companyId) =>
      _db.collection('companies').doc(companyId).collection('leaveRequests');

  Future<List<LeaveRequest>> loadMine({
    required String companyId,
    required String employeeId,
  }) async {
    final snapshot = await _requests(
      companyId,
    ).where('employeeId', isEqualTo: employeeId).get();

    final items =
        snapshot.docs
            .map((doc) => LeaveRequest.fromFirestore(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return List.unmodifiable(items);
  }

  Stream<List<LeaveRequest>> watchForApproval(String companyId) {
    return _requests(companyId)
        .where('status', isEqualTo: LeaveRequestStatus.pending.name)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => LeaveRequest.fromFirestore(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
          return List.unmodifiable(items);
        });
  }

  Stream<List<LeaveRequest>> watchApproved(String companyId) {
    return _requests(companyId)
        .where('status', isEqualTo: LeaveRequestStatus.approved.name)
        .snapshots()
        .map((snapshot) {
          return List.unmodifiable(
            snapshot.docs
                .map((doc) => LeaveRequest.fromFirestore(doc.id, doc.data()))
                .toList(),
          );
        });
  }

  Future<LeavePolicy> getPolicy() async {
    final callable = _functions.httpsCallable('getLeaveOverview');
    final result = await callable.call<Map<String, dynamic>>();
    final data = Map<String, dynamic>.from(result.data);
    final rawTypes = (data['types'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => LeaveTypePolicy.fromMap(Map<String, dynamic>.from(item)))
        .toList(growable: false);

    return LeavePolicy(
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      types: rawTypes,
    );
  }

  Future<LeaveOverview> getOverview() async {
    final callable = _functions.httpsCallable('getLeaveOverview');
    final result = await callable.call<Map<String, dynamic>>();
    final data = Map<String, dynamic>.from(result.data);
    final raw = (data['balances'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return LeaveBalanceItem(
            typeId: map['typeId'] as String? ?? '',
            typeName: map['typeName'] as String? ?? 'Leave',
            entitlement: (map['entitlement'] as num?)?.toDouble(),
            used: (map['used'] as num?)?.toDouble() ?? 0,
            reserved: (map['reserved'] as num?)?.toDouble() ?? 0,
          );
        })
        .toList(growable: false);

    return LeaveOverview(
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      balances: raw,
    );
  }

  Future<String> uploadAttachment({
    required String companyId,
    required String employeeId,
    required XFile file,
  }) async {
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        'companies/$companyId/leave/$employeeId/'
        '${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final ref = _storage.ref(path);
    await ref.putData(
      await file.readAsBytes(),
      SettableMetadata(contentType: file.mimeType),
    );
    return path;
  }

  Future<void> deleteAttachment(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (_) {
      // Best-effort cleanup for failed submissions.
    }
  }

  Future<void> submit({
    required String typeId,
    required String startDateKey,
    required String endDateKey,
    required LeaveDuration duration,
    required String reason,
    String? attachmentPath,
  }) async {
    final callable = _functions.httpsCallable('submitLeaveRequest');
    await callable.call<void>({
      'typeId': typeId,
      'startDateKey': startDateKey,
      'endDateKey': endDateKey,
      'duration': duration.name,
      'reason': reason.trim(),
      'attachmentPath': ?attachmentPath,
    });
  }

  Future<void> review({
    required String requestId,
    required LeaveRequestStatus status,
    String? note,
  }) async {
    final callable = _functions.httpsCallable('reviewLeaveRequest');
    await callable.call<void>({
      'requestId': requestId,
      'decision': status.name,
      'note': note?.trim() ?? '',
    });
  }

  Future<void> cancel(String requestId) async {
    final callable = _functions.httpsCallable('cancelLeaveRequest');
    await callable.call<void>({'requestId': requestId});
  }

  Future<void> updatePolicy(List<LeaveTypePolicy> types) async {
    final callable = _functions.httpsCallable('updateLeavePolicy');
    await callable.call<void>({
      'types': types.map((type) => type.toMap()).toList(growable: false),
    });
  }
}
