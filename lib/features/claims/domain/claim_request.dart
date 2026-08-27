import 'package:cloud_firestore/cloud_firestore.dart';

enum ClaimStatus { pending, approved, rejected, paid, cancelled }

extension ClaimStatusX on ClaimStatus {
  String get label => switch (this) {
    ClaimStatus.pending => 'Pending',
    ClaimStatus.approved => 'Approved',
    ClaimStatus.rejected => 'Rejected',
    ClaimStatus.paid => 'Paid',
    ClaimStatus.cancelled => 'Cancelled',
  };

  static ClaimStatus fromStorage(String? value) {
    return ClaimStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ClaimStatus.pending,
    );
  }
}

class ClaimRequest {
  const ClaimRequest({
    required this.id,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.title,
    required this.amount,
    required this.category,
    required this.expenseDate,
    required this.description,
    required this.submittedAt,
    required this.status,
    this.receiptPath,
    this.reviewedAt,
    this.reviewerId,
    this.reviewerName,
    this.reviewNote,
    this.paidAt,
    this.paidBy,
    this.paymentReference,
    this.cancelledAt,
  });

  final String id;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final String department;
  final String title;
  final double amount;
  final String category;
  final DateTime expenseDate;
  final String description;
  final DateTime submittedAt;
  final String? receiptPath;
  final ClaimStatus status;
  final DateTime? reviewedAt;
  final String? reviewerId;
  final String? reviewerName;
  final String? reviewNote;
  final DateTime? paidAt;
  final String? paidBy;
  final String? paymentReference;
  final DateTime? cancelledAt;

  factory ClaimRequest.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? timestamp(String key) => (data[key] as Timestamp?)?.toDate();

    DateTime expenseDate() {
      final timestampValue = data['expenseDate'];
      if (timestampValue is Timestamp) return timestampValue.toDate();
      final dateKey = data['expenseDateKey'] as String?;
      return dateKey == null
          ? DateTime.now()
          : DateTime.tryParse(dateKey) ?? DateTime.now();
    }

    return ClaimRequest(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      employeeId: data['employeeId'] as String? ?? '',
      employeeName: data['employeeName'] as String? ?? 'Employee',
      department: data['department'] as String? ?? '',
      title: data['title'] as String? ?? 'Expense claim',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      category: data['category'] as String? ?? 'Other',
      expenseDate: expenseDate(),
      description: data['description'] as String? ?? '',
      receiptPath: data['receiptPath'] as String?,
      submittedAt: timestamp('submittedAt') ?? DateTime.now(),
      status: ClaimStatusX.fromStorage(data['status'] as String?),
      reviewedAt: timestamp('reviewedAt'),
      reviewerId: data['reviewerId'] as String?,
      reviewerName: data['reviewerName'] as String?,
      reviewNote: data['reviewNote'] as String?,
      paidAt: timestamp('paidAt'),
      paidBy: data['paidBy'] as String?,
      paymentReference: data['paymentReference'] as String?,
      cancelledAt: timestamp('cancelledAt'),
    );
  }
}
