class CompanyProfile {
  const CompanyProfile({
    required this.id,
    required this.name,
    required this.status,
    this.registrationNumber = '',
    this.timeZone = 'Asia/Kuala_Lumpur',
  });

  final String id;
  final String name;
  final String status;
  final String registrationNumber;
  final String timeZone;
}
