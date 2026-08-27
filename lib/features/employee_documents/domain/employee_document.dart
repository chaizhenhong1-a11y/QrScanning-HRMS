import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeDocument {
  const EmployeeDocument({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.category,
    required this.fileName,
    required this.storagePath,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAt,
    this.expiryDateKey,
    this.notes,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String category;
  final String fileName;
  final String storagePath;
  final String contentType;
  final int sizeBytes;
  final DateTime? uploadedAt;
  final String? expiryDateKey;
  final String? notes;

  bool get hasExpiry => expiryDateKey?.isNotEmpty == true;

  factory EmployeeDocument.fromMap(String id, Map<String, dynamic> data) =>
      EmployeeDocument(
        id: id,
        employeeId: data['employeeId'] as String? ?? '',
        employeeName: data['employeeName'] as String? ?? 'Employee',
        category: data['category'] as String? ?? 'Other',
        fileName: data['fileName'] as String? ?? 'Document',
        storagePath: data['storagePath'] as String? ?? '',
        contentType:
            data['contentType'] as String? ?? 'application/octet-stream',
        sizeBytes: (data['sizeBytes'] as num?)?.toInt() ?? 0,
        uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
        expiryDateKey: data['expiryDateKey'] as String?,
        notes: data['notes'] as String?,
      );
}
