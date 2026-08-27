import 'package:image_picker/image_picker.dart';

import '../../../core/storage/session_store.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/leave_repository.dart';
import '../domain/leave_balance.dart';
import '../domain/leave_policy.dart';
import '../domain/leave_request.dart';

class LeaveService {
  LeaveService({LeaveRepository? repository})
    : _repository = repository ?? LeaveRepository();

  final LeaveRepository _repository;

  Future<({String companyId, String employeeId})> _session() async {
    final companyId = await SessionStore.getCompanyId();
    final employeeId = await SessionStore.getUserId();
    if (companyId == null ||
        companyId.isEmpty ||
        employeeId == null ||
        employeeId.isEmpty) {
      throw StateError('No active Veyra HRMS session.');
    }
    return (companyId: companyId, employeeId: employeeId);
  }

  Future<void> requireApprover() async {
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());
    if (!role.canApprove) {
      throw StateError('You do not have permission to review leave requests.');
    }
  }

  Future<List<LeaveRequest>> loadMine() async {
    final session = await _session();
    return _repository.loadMine(
      companyId: session.companyId,
      employeeId: session.employeeId,
    );
  }

  Future<LeavePolicy> policy() => _repository.getPolicy();

  Future<LeaveOverview> overview() => _repository.getOverview();

  Future<Stream<List<LeaveRequest>>> watchForApproval() async {
    await requireApprover();
    final session = await _session();
    return _repository
        .watchForApproval(session.companyId)
        .map(
          (items) => items
              .where((request) => request.employeeId != session.employeeId)
              .toList(growable: false),
        );
  }

  Future<Stream<List<LeaveRequest>>> watchApprovedForDate(
    String dateKey,
  ) async {
    await requireApprover();
    final session = await _session();
    return _repository
        .watchApproved(session.companyId)
        .map(
          (items) => items.where((request) => request.covers(dateKey)).toList(),
        );
  }

  Future<LeaveRequest?> approvedForDate(String dateKey) async {
    final mine = await loadMine();
    for (final request in mine) {
      if (request.covers(dateKey)) return request;
    }
    return null;
  }

  Future<void> submit({
    required String typeId,
    required DateTime startDate,
    required DateTime endDate,
    required LeaveDuration duration,
    required String reason,
    String? attachmentPath,
  }) {
    return _repository.submit(
      typeId: typeId,
      startDateKey: _dateKey(startDate),
      endDateKey: _dateKey(endDate),
      duration: duration,
      reason: reason,
      attachmentPath: attachmentPath,
    );
  }

  Future<String> uploadAttachment(XFile file) async {
    final session = await _session();
    return _repository.uploadAttachment(
      companyId: session.companyId,
      employeeId: session.employeeId,
      file: file,
    );
  }

  Future<void> deleteAttachment(String path) =>
      _repository.deleteAttachment(path);

  Future<void> review({
    required LeaveRequest request,
    required LeaveRequestStatus status,
    String? note,
  }) async {
    await requireApprover();
    if (status != LeaveRequestStatus.approved &&
        status != LeaveRequestStatus.rejected) {
      throw ArgumentError('Review decision must approve or reject.');
    }
    await _repository.review(requestId: request.id, status: status, note: note);
  }

  Future<void> cancel(LeaveRequest request) async {
    if (request.status != LeaveRequestStatus.pending) {
      throw StateError('Only pending leave requests can be cancelled.');
    }
    await _repository.cancel(request.id);
  }

  Future<void> updatePolicy(List<LeaveTypePolicy> types) async {
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());
    if (!role.canManageCompany) {
      throw StateError('Only company owners or HR can change leave policy.');
    }
    await _repository.updatePolicy(types);
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
