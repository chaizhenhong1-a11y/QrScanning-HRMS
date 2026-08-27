import 'package:image_picker/image_picker.dart';

import '../../../core/storage/session_store.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/claim_repository.dart';
import '../domain/claim_request.dart';

class ClaimService {
  ClaimService({ClaimRepository? repository})
    : _repository = repository ?? ClaimRepository();

  final ClaimRepository _repository;

  Future<({String companyId, String employeeId, String? firebaseUid})>
  _session() async {
    final companyId = await SessionStore.getCompanyId();
    final employeeId = await SessionStore.getUserId();
    final firebaseUid = await SessionStore.getFirebaseUid();

    if (companyId == null ||
        companyId.isEmpty ||
        employeeId == null ||
        employeeId.isEmpty) {
      throw StateError('No active Veyra HRMS session.');
    }

    return (
      companyId: companyId,
      employeeId: employeeId,
      firebaseUid: firebaseUid,
    );
  }

  Future<List<ClaimRequest>> loadMine() async {
    final session = await _session();
    return _repository.loadMine(
      companyId: session.companyId,
      employeeId: session.employeeId,
    );
  }

  Future<Stream<List<ClaimRequest>>> watchForApproval() async {
    final session = await _session();
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());

    if (!role.canApprove) {
      throw StateError('You do not have permission to review claims.');
    }

    return _repository
        .watchPendingForApproval(session.companyId)
        .map(
          (items) => items
              .where((claim) => claim.employeeId != session.employeeId)
              .toList(growable: false),
        );
  }

  Future<Stream<List<ClaimRequest>>> watchForPayment() async {
    final session = await _session();
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());

    if (!role.canManageCompany) {
      throw StateError('Only Company Owner or HR can mark claims as paid.');
    }

    return _repository.watchApprovedForPayment(session.companyId);
  }

  Future<String> uploadReceipt(XFile file) async {
    final session = await _session();
    return _repository.uploadReceipt(
      companyId: session.companyId,
      employeeId: session.employeeId,
      file: file,
    );
  }

  Future<void> deleteReceipt(String path) => _repository.deleteReceipt(path);

  Future<void> submit({
    required String title,
    required double amount,
    required String category,
    required DateTime expenseDate,
    required String description,
    String? receiptPath,
  }) {
    return _repository.submit(
      title: title,
      amount: amount,
      category: category,
      expenseDate: expenseDate,
      description: description,
      receiptPath: receiptPath,
    );
  }

  Future<void> review({
    required ClaimRequest request,
    required ClaimStatus status,
    String? note,
  }) async {
    if (status != ClaimStatus.approved && status != ClaimStatus.rejected) {
      throw ArgumentError('A review must approve or reject the claim.');
    }
    await _repository.review(claimId: request.id, status: status, note: note);
  }

  Future<void> cancel(ClaimRequest request) async {
    if (request.status != ClaimStatus.pending) {
      throw StateError('Only pending claims can be cancelled.');
    }
    await _repository.cancel(request.id);
  }

  Future<void> markPaid({
    required ClaimRequest request,
    String? paymentReference,
  }) {
    return _repository.markPaid(
      claimId: request.id,
      paymentReference: paymentReference,
    );
  }
}
