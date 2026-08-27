import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/attendance_action_result.dart';
import '../domain/attendance_entry.dart';
import '../domain/attendance_settings.dart';

class AttendanceRepository {
  AttendanceRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseServices.firestore,
       _functions = functions ?? FirebaseServices.functions;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> _attendance(String companyId) =>
      _db.collection('companies').doc(companyId).collection('attendance');

  DocumentReference<Map<String, dynamic>> _settings(String companyId) => _db
      .collection('companies')
      .doc(companyId)
      .collection('settings')
      .doc('attendance');

  Future<AttendanceActionResult> clock({
    required String source,
    String? qrToken,
  }) async {
    final callable = _functions.httpsCallable('clockAttendance');
    final result = await callable.call<Map<String, dynamic>>({
      'source': source,
      'qrToken': ?qrToken,
    });

    final data = Map<String, dynamic>.from(result.data);
    return AttendanceActionResult(
      action: data['action'] as String? ?? '',
      dateKey: data['dateKey'] as String? ?? '',
      status: data['status'] as String? ?? '',
      message: data['message'] as String? ?? 'Attendance recorded.',
    );
  }

  Future<String> issueQr() async {
    final callable = _functions.httpsCallable('issueAttendanceQr');
    final result = await callable.call<Map<String, dynamic>>();
    final token = result.data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Attendance QR service returned an invalid token.');
    }
    return token;
  }

  Future<AttendanceSettings> getSettings(String companyId) async {
    final snapshot = await _settings(companyId).get();
    final data = snapshot.data();
    if (data == null) return AttendanceSettings.defaults;

    return AttendanceSettings(
      workStartMinutes:
          (data['workStartMinutes'] as num?)?.toInt() ??
          AttendanceSettings.defaults.workStartMinutes,
      workEndMinutes:
          (data['workEndMinutes'] as num?)?.toInt() ??
          AttendanceSettings.defaults.workEndMinutes,
      graceMinutes:
          (data['graceMinutes'] as num?)?.toInt() ??
          AttendanceSettings.defaults.graceMinutes,
      requireQr:
          data['requireQr'] as bool? ?? AttendanceSettings.defaults.requireQr,
      timeZone:
          data['timeZone'] as String? ?? AttendanceSettings.defaults.timeZone,
    );
  }

  Future<void> updateSettings(AttendanceSettings settings) async {
    final callable = _functions.httpsCallable('updateAttendanceSettings');
    await callable.call<void>({
      'workStartMinutes': settings.workStartMinutes,
      'workEndMinutes': settings.workEndMinutes,
      'graceMinutes': settings.graceMinutes,
      'requireQr': settings.requireQr,
      'timeZone': settings.timeZone,
    });
  }

  Future<AttendanceEntry?> getToday({
    required String companyId,
    required String employeeId,
  }) async {
    final query = await _attendance(
      companyId,
    ).where('employeeId', isEqualTo: employeeId).get();

    if (query.docs.isEmpty) return null;

    final entries =
        query.docs
            .map((doc) => AttendanceEntry.fromFirestore(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.dateKey.compareTo(a.dateKey));

    return entries.first;
  }

  Future<List<AttendanceEntry>> getEmployeeHistory({
    required String companyId,
    required String employeeId,
    int limit = 90,
  }) async {
    final query = await _attendance(
      companyId,
    ).where('employeeId', isEqualTo: employeeId).get();

    final entries =
        query.docs
            .map((doc) => AttendanceEntry.fromFirestore(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.dateKey.compareTo(a.dateKey));

    if (entries.length <= limit) {
      return List<AttendanceEntry>.unmodifiable(entries);
    }
    return List<AttendanceEntry>.unmodifiable(entries.take(limit));
  }

  Stream<List<AttendanceEntry>> watchTeamForDate({
    required String companyId,
    required String dateKey,
  }) {
    return _attendance(
      companyId,
    ).where('dateKey', isEqualTo: dateKey).snapshots().map((snapshot) {
      final entries =
          snapshot.docs
              .map((doc) => AttendanceEntry.fromFirestore(doc.id, doc.data()))
              .toList()
            ..sort(
              (a, b) => a.employeeName.toLowerCase().compareTo(
                b.employeeName.toLowerCase(),
              ),
            );
      return List<AttendanceEntry>.unmodifiable(entries);
    });
  }
}
