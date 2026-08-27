import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../application/report_service.dart';
import '../../domain/monthly_hr_report.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _service = ReportService();
  late String _month;
  late Future<MonthlyHrReport> _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _future = _service.loadMonthly(_month);
  }

  void _reload() {
    setState(() => _future = _service.loadMonthly(_month));
  }

  Future<void> _pickMonth() async {
    final parts = _month.split('-');
    final current = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      helpText: 'Choose any day in the report month',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _month = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      _future = _service.loadMonthly(_month);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            tooltip: 'Change month',
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: FutureBuilder<MonthlyHrReport>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 180),
                    const Icon(
                      Icons.analytics_outlined,
                      size: 54,
                      color: VeyraDesign.muted,
                    ),
                    const SizedBox(height: 12),
                    const Center(child: Text('Unable to load HR report.')),
                    const SizedBox(height: 12),
                    Center(
                      child: FilledButton(
                        onPressed: _reload,
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                );
              }

              final report = snapshot.data!;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                children: [
                  _ReportHero(report: report, onCopy: () => _copy(report)),
                  const SizedBox(height: 18),
                  _sectionTitle('Workforce'),
                  _grid([
                    _Metric(
                      icon: Icons.groups_rounded,
                      label: 'Active employees',
                      value: '${report.activeEmployees}',
                    ),
                    _Metric(
                      icon: Icons.badge_outlined,
                      label: 'Employees present',
                      value: '${report.presentEmployees}',
                    ),
                  ]),
                  const SizedBox(height: 18),
                  _sectionTitle('Attendance'),
                  _grid([
                    _Metric(
                      icon: Icons.fact_check_outlined,
                      label: 'Records',
                      value: '${report.attendanceRecords}',
                    ),
                    _Metric(
                      icon: Icons.task_alt_rounded,
                      label: 'Completed',
                      value: '${report.completedAttendanceRecords}',
                    ),
                    _Metric(
                      icon: Icons.schedule_rounded,
                      label: 'Late',
                      value: '${report.lateRecords}',
                    ),
                    _Metric(
                      icon: Icons.logout_rounded,
                      label: 'Early leave',
                      value: '${report.earlyLeaveRecords}',
                    ),
                  ]),
                  const SizedBox(height: 18),
                  _sectionTitle('Leave'),
                  _grid([
                    _Metric(
                      icon: Icons.beach_access_rounded,
                      label: 'Approved requests',
                      value: '${report.approvedLeaveRequests}',
                    ),
                    _Metric(
                      icon: Icons.calendar_today_outlined,
                      label: 'Approved days',
                      value: _number(report.approvedLeaveDays),
                    ),
                    _Metric(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending requests',
                      value: '${report.pendingLeaveRequests}',
                    ),
                  ]),
                  const SizedBox(height: 18),
                  _sectionTitle('Expense claims'),
                  _grid([
                    _Metric(
                      icon: Icons.receipt_long_rounded,
                      label: 'Claims',
                      value: '${report.claimCount}',
                    ),
                    _Metric(
                      icon: Icons.hourglass_top_rounded,
                      label: 'Pending',
                      value: '${report.pendingClaimCount}',
                    ),
                    _Metric(
                      icon: Icons.verified_outlined,
                      label: 'Approved',
                      value: '${report.approvedClaimCount}',
                    ),
                    _Metric(
                      icon: Icons.payments_outlined,
                      label: 'Total amount',
                      value: 'RM ${report.claimAmount.toStringAsFixed(2)}',
                    ),
                  ]),
                  if (report.payrollVisible) ...[
                    const SizedBox(height: 18),
                    _sectionTitle('Payroll'),
                    _grid([
                      _Metric(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Status',
                        value: report.payrollStatus?.toUpperCase() ?? 'NONE',
                      ),
                      _Metric(
                        icon: Icons.people_alt_outlined,
                        label: 'Employees',
                        value: '${report.payrollEmployeeCount}',
                      ),
                      _Metric(
                        icon: Icons.monetization_on_outlined,
                        label: 'Total net pay',
                        value: 'RM ${report.totalNetPay.toStringAsFixed(2)}',
                      ),
                    ]),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w900,
        color: VeyraDesign.ink,
      ),
    ),
  );

  Widget _grid(List<_Metric> items) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 720 ? 4 : 2;
      final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map((item) => SizedBox(width: width, child: item))
            .toList(growable: false),
      );
    },
  );

  Future<void> _copy(MonthlyHrReport report) async {
    final lines = <String>[
      'Veyra HRMS Monthly Report - ${report.month}',
      'Active employees: ${report.activeEmployees}',
      'Attendance records: ${report.attendanceRecords}',
      'Completed attendance: ${report.completedAttendanceRecords}',
      'Late records: ${report.lateRecords}',
      'Early leave records: ${report.earlyLeaveRecords}',
      'Approved leave: ${report.approvedLeaveRequests} requests / ${_number(report.approvedLeaveDays)} days',
      'Pending leave: ${report.pendingLeaveRequests}',
      'Claims: ${report.claimCount}',
      'Pending claims: ${report.pendingClaimCount}',
      'Approved claims: ${report.approvedClaimCount}',
      'Paid claims: ${report.paidClaimCount}',
      'Claim amount: RM ${report.claimAmount.toStringAsFixed(2)}',
      if (report.payrollVisible)
        'Payroll: ${report.payrollStatus ?? 'none'} / RM ${report.totalNetPay.toStringAsFixed(2)}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Monthly report copied.')));
  }

  static String _number(double value) =>
      value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.report, required this.onCopy});

  final MonthlyHrReport report;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: VeyraDesign.brandGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            child: Icon(Icons.analytics_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.month,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(report.attendanceCompletionRate * 100).toStringAsFixed(0)}% attendance records completed',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy report',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: VeyraDesign.primary),
            const SizedBox(height: 14),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: VeyraDesign.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
