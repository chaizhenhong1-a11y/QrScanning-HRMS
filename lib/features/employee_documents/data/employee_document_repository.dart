import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/firebase/firebase_services.dart';
import '../domain/employee_document.dart';

class EmployeeDocumentRepository {
  EmployeeDocumentRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  }) : _db = firestore ?? FirebaseServices.firestore,
       _functions = functions ?? FirebaseServices.functions,
       _storage = storage ?? FirebaseServices.storage;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _documents(String companyId) => _db
      .collection('companies')
      .doc(companyId)
      .collection('employeeDocuments');

  Future<List<EmployeeDocument>> load({
    required String companyId,
    required String employeeId,
    required bool managementView,
  }) async {
    Query<Map<String, dynamic>> query = _documents(companyId);
    if (!managementView) {
      query = query.where('employeeId', isEqualTo: employeeId);
    }
    final snapshot = await query.limit(200).get();
    final items =
        snapshot.docs
            .map((doc) => EmployeeDocument.fromMap(doc.id, doc.data()))
            .toList()
          ..sort(
            (a, b) => (b.uploadedAt ?? DateTime(1970)).compareTo(
              a.uploadedAt ?? DateTime(1970),
            ),
          );
    return List.unmodifiable(items);
  }

  Future<PlatformFile?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    return result?.files.single;
  }

  Future<String> upload({
    required String companyId,
    required String employeeId,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError('Unable to read the selected file.');
    }
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        'companies/$companyId/employee_documents/$employeeId/'
        '${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _storage
        .ref(path)
        .putData(
          bytes,
          SettableMetadata(contentType: _contentType(file.extension)),
        );
    return path;
  }

  Future<void> register({
    required String employeeId,
    required String category,
    required String fileName,
    required String storagePath,
    required String contentType,
    required int sizeBytes,
    String? expiryDateKey,
    String? notes,
  }) => _functions.httpsCallable('registerEmployeeDocument').call<void>({
    'employeeId': employeeId,
    'category': category,
    'fileName': fileName,
    'storagePath': storagePath,
    'contentType': contentType,
    'sizeBytes': sizeBytes,
    'expiryDateKey': ?expiryDateKey,
    'notes': ?notes,
  });

  Future<String> downloadUrl(String storagePath) =>
      _storage.ref(storagePath).getDownloadURL();

  Future<void> delete(String documentId) => _functions
      .httpsCallable('deleteEmployeeDocument')
      .call<void>({'documentId': documentId});

  static String _contentType(String? extension) =>
      switch (extension?.toLowerCase()) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/octet-stream',
      };
}
