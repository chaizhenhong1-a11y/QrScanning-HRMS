import 'package:file_picker/file_picker.dart';

import '../../../core/storage/session_store.dart';
import '../../identity/domain/hrms_role.dart';
import '../data/employee_document_repository.dart';
import '../domain/employee_document.dart';

class EmployeeDocumentService {
  EmployeeDocumentService({EmployeeDocumentRepository? repository})
    : _repository = repository ?? EmployeeDocumentRepository();

  final EmployeeDocumentRepository _repository;

  Future<({String companyId, String employeeId, HrmsRole role})>
  _session() async {
    final companyId = await SessionStore.getCompanyId();
    final employeeId = await SessionStore.getUserId();
    final role = HrmsRole.fromValue(await SessionStore.getHrmsRole());
    if (companyId == null || employeeId == null) {
      throw StateError('No active Veyra HRMS session.');
    }
    return (companyId: companyId, employeeId: employeeId, role: role);
  }

  Future<List<EmployeeDocument>> load() async {
    final session = await _session();
    return _repository.load(
      companyId: session.companyId,
      employeeId: session.employeeId,
      managementView: session.role.canManageCompany,
    );
  }

  Future<PlatformFile?> pickDocument() => _repository.pickDocument();

  Future<void> uploadAndRegister({
    required PlatformFile file,
    required String targetEmployeeId,
    required String category,
    String? expiryDateKey,
    String? notes,
  }) async {
    final session = await _session();
    if (targetEmployeeId != session.employeeId &&
        !session.role.canManageCompany) {
      throw StateError('You cannot upload documents for another employee.');
    }

    final path = await _repository.upload(
      companyId: session.companyId,
      employeeId: targetEmployeeId,
      file: file,
    );

    try {
      await _repository.register(
        employeeId: targetEmployeeId,
        category: category,
        fileName: file.name,
        storagePath: path,
        contentType: _contentType(file.extension),
        sizeBytes: file.size,
        expiryDateKey: expiryDateKey,
        notes: notes,
      );
    } catch (_) {
      rethrow;
    }
  }

  Future<String> downloadUrl(EmployeeDocument document) =>
      _repository.downloadUrl(document.storagePath);

  Future<void> delete(EmployeeDocument document) =>
      _repository.delete(document.id);

  static String _contentType(String? extension) =>
      switch (extension?.toLowerCase()) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        _ => 'application/octet-stream',
      };
}
