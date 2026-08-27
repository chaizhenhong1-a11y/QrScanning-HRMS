class LeaveTypePolicy {
  const LeaveTypePolicy({
    required this.id,
    required this.name,
    required this.quotaDays,
    required this.paid,
    required this.requiresAttachment,
  });

  final String id;
  final String name;
  final double? quotaDays;
  final bool paid;
  final bool requiresAttachment;

  bool get hasQuota => quotaDays != null;

  factory LeaveTypePolicy.fromMap(Map<String, dynamic> data) {
    return LeaveTypePolicy(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'Leave',
      quotaDays: (data['quotaDays'] as num?)?.toDouble(),
      paid: data['paid'] as bool? ?? true,
      requiresAttachment: data['requiresAttachment'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'quotaDays': quotaDays,
    'paid': paid,
    'requiresAttachment': requiresAttachment,
  };
}

class LeavePolicy {
  const LeavePolicy({required this.year, required this.types});

  final int year;
  final List<LeaveTypePolicy> types;

  LeaveTypePolicy? byId(String id) {
    for (final type in types) {
      if (type.id == id) return type;
    }
    return null;
  }
}
