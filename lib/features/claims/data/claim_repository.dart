import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/claim_request.dart';

class ClaimRepository {
  ClaimRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  }) : _db = firestore ?? FirebaseServices.firestore,
       _functions = functions ?? FirebaseServices.functions,
       _storage = storage ?? FirebaseServices.storage;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _claims(String companyId) =>
      _db.collection('companies').doc(companyId).collection('claimRequests');

  Future<List<ClaimRequest>> loadMine({
    required String companyId,
    required String employeeId,
  }) async {
    final snapshot = await _claims(
      companyId,
    ).where('employeeId', isEqualTo: employeeId).limit(100).get();

    final items =
        snapshot.docs
            .map((doc) => ClaimRequest.fromFirestore(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return List.unmodifiable(items);
  }

  Stream<List<ClaimRequest>> watchPendingForApproval(String companyId) {
    return _claims(companyId)
        .where('status', isEqualTo: ClaimStatus.pending.name)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => ClaimRequest.fromFirestore(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
          return List.unmodifiable(items);
        });
  }

  Stream<List<ClaimRequest>> watchApprovedForPayment(String companyId) {
    return _claims(
      companyId,
    ).where('status', isEqualTo: ClaimStatus.approved.name).snapshots().map((
      snapshot,
    ) {
      final items =
          snapshot.docs
              .map((doc) => ClaimRequest.fromFirestore(doc.id, doc.data()))
              .toList()
            ..sort(
              (a, b) =>
                  a.reviewedAt.toString().compareTo(b.reviewedAt.toString()),
            );
      return List.unmodifiable(items);
    });
  }

  Future<String> uploadReceipt({
    required String companyId,
    required String employeeId,
    required XFile file,
  }) async {
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        'companies/$companyId/claims/$employeeId/'
        '${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final ref = _storage.ref(path);
    await ref.putData(
      await file.readAsBytes(),
      SettableMetadata(contentType: file.mimeType),
    );
    return path;
  }

  Future<void> deleteReceipt(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (_) {
      // Best-effort cleanup for failed submissions.
    }
  }

  Future<void> submit({
    required String title,
    required double amount,
    required String category,
    required DateTime expenseDate,
    required String description,
    String? receiptPath,
  }) async {
    final callable = _functions.httpsCallable('submitExpenseClaimV2');
    await callable.call<void>({
      'title': title.trim(),
      'amount': amount,
      'category': category,
      'expenseDateKey': _dateKey(expenseDate),
      'description': description.trim(),
      'receiptPath': ?receiptPath,
    });
  }

  Future<void> review({
    required String claimId,
    required ClaimStatus status,
    String? note,
  }) async {
    final callable = _functions.httpsCallable('reviewExpenseClaimV2');
    await callable.call<void>({
      'claimId': claimId,
      'decision': status.name,
      'note': note?.trim() ?? '',
    });
  }

  Future<void> cancel(String claimId) async {
    final callable = _functions.httpsCallable('cancelExpenseClaimV2');
    await callable.call<void>({'claimId': claimId});
  }

  Future<void> markPaid({
    required String claimId,
    String? paymentReference,
  }) async {
    final callable = _functions.httpsCallable('markExpenseClaimPaidV2');
    await callable.call<void>({
      'claimId': claimId,
      'paymentReference': paymentReference?.trim() ?? '',
    });
  }

  static String _dateKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
