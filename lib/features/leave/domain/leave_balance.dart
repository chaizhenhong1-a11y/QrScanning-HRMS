class LeaveBalanceItem {
  const LeaveBalanceItem({
    required this.typeId,
    required this.typeName,
    required this.entitlement,
    required this.used,
    required this.reserved,
  });

  final String typeId;
  final String typeName;
  final double? entitlement;
  final double used;
  final double reserved;

  bool get hasQuota => entitlement != null;
  double? get remaining =>
      entitlement == null ? null : entitlement! - used - reserved;
}

class LeaveOverview {
  const LeaveOverview({required this.year, required this.balances});

  final int year;
  final List<LeaveBalanceItem> balances;

  LeaveBalanceItem? byType(String id) {
    for (final item in balances) {
      if (item.typeId == id) return item;
    }
    return null;
  }
}
