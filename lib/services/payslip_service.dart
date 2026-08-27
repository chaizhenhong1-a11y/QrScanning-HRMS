class PayslipService {
  // 模拟数据
  static List<Map<String, dynamic>> getPayslips(String userId) {
    return [
      {
        'month': '2026-05',
        'basic': 5000.0,
        'allowance': 500.0,
        'deduction': 200.0,
        'net': 5300.0,
      },
      {
        'month': '2026-04',
        'basic': 5000.0,
        'allowance': 400.0,
        'deduction': 150.0,
        'net': 5250.0,
      },
    ];
  }
}
