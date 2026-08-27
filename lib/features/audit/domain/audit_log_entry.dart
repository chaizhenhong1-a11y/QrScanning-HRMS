import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.module,
    required this.action,
    required this.actorUid,
    required this.actorEmployeeId,
    required this.actorName,
    required this.targetType,
    required this.targetId,
    required this.summary,
    required this.result,
    this.createdAt,
  });

  final String id;
  final String module;
  final String action;
  final String actorUid;
  final String actorEmployeeId;
  final String actorName;
  final String targetType;
  final String targetId;
  final String summary;
  final String result;
  final DateTime? createdAt;

  factory AuditLogEntry.fromMap(String id, Map<String, dynamic> data) =>
      AuditLogEntry(
        id: id,
        module: data['module'] as String? ?? 'system',
        action: data['action'] as String? ?? 'unknown',
        actorUid: data['actorUid'] as String? ?? '',
        actorEmployeeId: data['actorEmployeeId'] as String? ?? '',
        actorName: data['actorName'] as String? ?? 'Unknown',
        targetType: data['targetType'] as String? ?? '',
        targetId: data['targetId'] as String? ?? '',
        summary: data['summary'] as String? ?? '',
        result: data['result'] as String? ?? 'success',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );
}
