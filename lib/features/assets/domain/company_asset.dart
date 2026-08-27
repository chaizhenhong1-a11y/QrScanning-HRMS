class CompanyAsset {
  const CompanyAsset({
    required this.id,
    required this.assetTag,
    required this.name,
    required this.category,
    required this.status,
    required this.serialNumber,
    this.assignedEmployeeId,
    this.assignedEmployeeName,
    this.purchaseDateKey,
    this.warrantyExpiryDateKey,
    this.notes,
  });

  final String id;
  final String assetTag;
  final String name;
  final String category;
  final String status;
  final String serialNumber;
  final String? assignedEmployeeId;
  final String? assignedEmployeeName;
  final String? purchaseDateKey;
  final String? warrantyExpiryDateKey;
  final String? notes;

  bool get isAssigned => status == 'assigned';

  factory CompanyAsset.fromMap(Map<String, dynamic> data) => CompanyAsset(
    id: data['id'] as String? ?? '',
    assetTag: data['assetTag'] as String? ?? '',
    name: data['name'] as String? ?? 'Asset',
    category: data['category'] as String? ?? 'Other',
    status: data['status'] as String? ?? 'available',
    serialNumber: data['serialNumber'] as String? ?? '',
    assignedEmployeeId: data['assignedEmployeeId'] as String?,
    assignedEmployeeName: data['assignedEmployeeName'] as String?,
    purchaseDateKey: data['purchaseDateKey'] as String?,
    warrantyExpiryDateKey: data['warrantyExpiryDateKey'] as String?,
    notes: data['notes'] as String?,
  );
}
