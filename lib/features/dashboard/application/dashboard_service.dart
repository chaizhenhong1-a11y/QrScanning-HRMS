import 'package:flutter/foundation.dart';

import '../../../core/storage/session_store.dart';
import '../../../services/user_service.dart';
import '../../attendance/application/attendance_service.dart';
import '../../attendance/domain/attendance_entry.dart';
import '../../attendance/domain/attendance_settings.dart';
import '../../claims/application/claim_service.dart';
import '../../claims/domain/claim_request.dart';
import '../../leave/application/leave_service.dart';
import '../../leave/domain/leave_request.dart';
import '../domain/dashboard_snapshot.dart';

abstract final class DashboardService {
  static Future<DashboardSnapshot> load() async {
    final userId = await SessionStore.getUserId();
    if (userId == null || userId.isEmpty) {
      throw const DashboardSessionException();
    }

    final user = UserService.getUserById(userId);
    if (user == null) {
      throw const DashboardSessionException();
    }

    final attendance = AttendanceApplicationService();

    final settings = await _safe<AttendanceSettings>(
      label: 'attendance settings',
      task: attendance.settings,
      fallback: AttendanceSettings.defaults,
    );

    final today = await _safeNullable<AttendanceEntry>(
      label: 'today attendance',
      task: attendance.today,
    );

    final history = await _safe<List<AttendanceEntry>>(
      label: 'attendance history',
      task: attendance.history,
      fallback: const <AttendanceEntry>[],
    );

    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final leaveToday = await _safeNullable<LeaveRequest>(
      label: 'approved leave',
      task: () => LeaveService().approvedForDate(dateKey),
    );

    final claims = await _safe<List<ClaimRequest>>(
      label: 'claims summary',
      task: ClaimService().loadMine,
      fallback: const <ClaimRequest>[],
    );

    final pendingClaimCount = claims
        .where((claim) => claim.status == ClaimStatus.pending)
        .length;

    final monthEntries = history.where((entry) {
      final parts = entry.dateKey.split('-');
      if (parts.length != 3) return false;
      return int.tryParse(parts[0]) == now.year &&
          int.tryParse(parts[1]) == now.month;
    }).toList();

    return DashboardSnapshot(
      userId: user.id,
      userName: user.name,
      department: user.department,
      role: user.role,
      workStartLabel: settings.workStartLabel,
      workEndLabel: settings.workEndLabel,
      clockInTime: _time(today?.clockInAt),
      clockOutTime: _time(today?.clockOutAt),
      clockInStatus: _status(today?.clockInStatus),
      clockOutStatus: _status(today?.clockOutStatus),
      monthLoggedDays: monthEntries.length,
      monthLateCount: monthEntries.where((entry) => entry.isLate).length,
      monthEarlyCount: monthEntries.where((entry) => entry.leftEarly).length,
      monthNormalCount: monthEntries
          .where((entry) => !entry.isLate && !entry.leftEarly)
          .length,
      leaveTodayType: leaveToday?.typeName,
      pendingClaimCount: pendingClaimCount,
    );
  }

  static Future<T> _safe<T>({
    required String label,
    required Future<T> Function() task,
    required T fallback,
  }) async {
    try {
      return await task();
    } catch (error, stackTrace) {
      debugPrint('Dashboard optional module failed [$label]: $error');
      debugPrintStack(stackTrace: stackTrace);
      return fallback;
    }
  }

  static Future<T?> _safeNullable<T>({
    required String label,
    required Future<T?> Function() task,
  }) async {
    try {
      return await task();
    } catch (error, stackTrace) {
      debugPrint('Dashboard optional module failed [$label]: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  static String? _time(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String? _status(String? value) => switch (value) {
    'late' => 'Late',
    'onTime' => 'Normal',
    'early' => 'Early',
    'normal' => 'Normal',
    _ => null,
  };
}

class DashboardSessionException implements Exception {
  const DashboardSessionException();

  @override
  String toString() => 'The authenticated HRMS session could not be restored.';
}
