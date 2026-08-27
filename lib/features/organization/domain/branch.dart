class CompanyBranch {
  const CompanyBranch({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    this.address = '',
  });

  final String id;
  final String name;
  final String code;
  final bool isActive;
  final String address;
}
