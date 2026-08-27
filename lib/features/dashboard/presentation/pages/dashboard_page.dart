import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';

import '../../../../screens/claims_screen.dart';
import '../../../../screens/company_policy_screen.dart';
import '../../../../screens/flexible_work_screen.dart';
import '../../../../screens/history_screen.dart';
import '../../../../screens/hr_memos_screen.dart';
import '../../../../screens/income_tax_screen.dart';
import '../../../../screens/leave_screen.dart';
import '../../../../screens/meeting_room_screen.dart';
import '../../../../screens/payslip_screen.dart';
import '../../../../screens/rewards_screen.dart';
import '../../../../screens/training_feedback_screen.dart';
import '../../../attendance/presentation/pages/team_attendance_page.dart';
import '../../../employees/presentation/pages/employee_directory_page.dart';
import '../../../identity/domain/hrms_role.dart';
import '../../../leave/presentation/pages/approvals_page.dart';
import '../../../leave/presentation/pages/leave_policy_page.dart';
import '../../../organization/presentation/pages/organization_page.dart';
import '../../application/dashboard_service.dart';
import '../../domain/dashboard_snapshot.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.role,
    required this.hrmsRole,
    required this.onAttendanceAction,
    this.refreshToken = 0,
  });

  final String role;
  final HrmsRole hrmsRole;
  final VoidCallback onAttendanceAction;
  final int refreshToken;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<DashboardSnapshot> _snapshotFuture;

  static final _quickActions = <_QuickAction>[
    _QuickAction(
      'Leave',
      Icons.beach_access_rounded,
      () => const LeaveScreen(),
    ),
    _QuickAction(
      'Claims',
      Icons.receipt_long_rounded,
      () => const ClaimsScreen(),
    ),
    _QuickAction(
      'Payslip',
      Icons.description_rounded,
      () => const PayslipScreen(),
    ),
    _QuickAction(
      'HR Memos',
      Icons.campaign_rounded,
      () => const HrMemosScreen(),
    ),
    _QuickAction(
      'Meeting Room',
      Icons.meeting_room_rounded,
      () => const MeetingRoomScreen(),
    ),
    _QuickAction(
      'Policy',
      Icons.policy_rounded,
      () => const CompanyPolicyScreen(),
    ),
    _QuickAction(
      'Flexible Work',
      Icons.work_outline_rounded,
      () => const FlexibleWorkScreen(),
    ),
    _QuickAction(
      'Income Tax',
      Icons.account_balance_rounded,
      () => const IncomeTaxScreen(),
    ),
    _QuickAction(
      'Training',
      Icons.school_rounded,
      () => const TrainingFeedbackScreen(),
    ),
    _QuickAction(
      'Rewards',
      Icons.card_giftcard_rounded,
      () => const RewardsScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _snapshotFuture = DashboardService.load();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _snapshotFuture = DashboardService.load();
    });
  }

  Future<void> _refresh() async {
    _reload();
    await _snapshotFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: SafeArea(
          child: FutureBuilder<DashboardSnapshot>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                debugPrint('Dashboard core load failed: ${snapshot.error}');
              }

              if (!snapshot.hasData) {
                return _DashboardError(onRetry: _reload);
              }

              final data = snapshot.data!;
              return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      sliver: SliverToBoxAdapter(child: _Header(data: data)),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _TodayAttendanceCard(
                          data: data,
                          role: widget.role,
                          onAttendanceAction: widget.onAttendanceAction,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      sliver: const SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: 'This month',
                          subtitle: 'Your attendance overview',
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _MonthlyStats(data: data),
                      ),
                    ),
                    if (widget.hrmsRole.canApprove)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              leading: const CircleAvatar(
                                child: Icon(Icons.approval_rounded),
                              ),
                              title: const Text(
                                'Manager approvals',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: const Text(
                                'Review employee leave requests and expense claims',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ApprovalsPage(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.hrmsRole.canManageCompany)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        sliver: const SliverToBoxAdapter(
                          child: _CompanyAdministrationCard(),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: 'Work tools',
                          subtitle: 'Frequently used employee services',
                          trailing: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const HistoryScreen(),
                              ),
                            ),
                            child: const Text('History'),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _QuickActionTile(action: _quickActions[index]),
                          childCount: _quickActions.length,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 180,
                              mainAxisExtent: 104,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CompanyAdministrationCard extends StatelessWidget {
  const _CompanyAdministrationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Company administration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your organization and workforce',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 150,
                  child: _AdminAction(
                    icon: Icons.account_tree_outlined,
                    label: 'Company structure',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OrganizationPage(),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _AdminAction(
                    icon: Icons.groups_2_outlined,
                    label: 'Employees',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EmployeeDirectoryPage(),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _AdminAction(
                    icon: Icons.fact_check_outlined,
                    label: 'Attendance',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TeamAttendancePage(),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _AdminAction(
                    icon: Icons.beach_access_outlined,
                    label: 'Leave policy',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LeavePolicyPage(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAction extends StatelessWidget {
  const _AdminAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final DashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
        ? 'Good afternoon'
        : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: VeyraDesign.muted),
              ),
              const SizedBox(height: 2),
              Text(
                data.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: VeyraDesign.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.department} · ${data.roleLabel}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: VeyraDesign.muted),
              ),
            ],
          ),
        ),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7FF),
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: Text(
            _initial(data.userName),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }

  static String _initial(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }
}

class _TodayAttendanceCard extends StatelessWidget {
  const _TodayAttendanceCard({
    required this.data,
    required this.role,
    required this.onAttendanceAction,
  });

  final DashboardSnapshot data;
  final String role;
  final VoidCallback onAttendanceAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBoss = role == 'boss';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [VeyraDesign.primary, VeyraDesign.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x224FACFE),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Today attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(
                label: data.isOnLeaveToday
                    ? 'On leave'
                    : data.attendanceCompleted
                    ? 'Completed'
                    : data.hasClockedIn
                    ? 'In progress'
                    : 'Not started',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Work schedule ${data.workStartLabel} – ${data.workEndLabel}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _AttendanceTime(
                  icon: Icons.login_rounded,
                  label: 'Clock in',
                  time: data.clockInTime ?? '--:--',
                  status: data.clockInStatus,
                ),
              ),
              Container(width: 1, height: 54, color: Colors.white24),
              Expanded(
                child: _AttendanceTime(
                  icon: Icons.logout_rounded,
                  label: 'Clock out',
                  time: data.clockOutTime ?? '--:--',
                  status: data.clockOutStatus,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: scheme.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: data.isOnLeaveToday ? null : onAttendanceAction,
              icon: Icon(
                data.isOnLeaveToday
                    ? Icons.beach_access_rounded
                    : isBoss
                    ? Icons.qr_code_2_rounded
                    : Icons.qr_code_scanner_rounded,
              ),
              label: Text(
                data.isOnLeaveToday
                    ? 'Approved leave · ${data.leaveTodayType}'
                    : isBoss
                    ? 'Open company attendance code'
                    : 'Scan attendance QR',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTime extends StatelessWidget {
  const _AttendanceTime({
    required this.icon,
    required this.label,
    required this.time,
    required this.status,
  });

  final IconData icon;
  final String label;
  final String time;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: 2),
            Text(
              status!,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MonthlyStats extends StatelessWidget {
  const _MonthlyStats({required this.data});

  final DashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Days logged',
            value: '${data.monthLoggedDays}',
            icon: Icons.calendar_month_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Late',
            value: '${data.monthLateCount}',
            icon: Icons.schedule_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Early leave',
            value: '${data.monthEarlyCount}',
            icon: Icons.exit_to_app_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VeyraDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: VeyraDesign.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE8EDF3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => action.builder())),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, size: 20, color: VeyraDesign.primary),
              ),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load your dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check your session and try again.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

typedef _PageBuilder = Widget Function();

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.builder);

  final String label;
  final IconData icon;
  final _PageBuilder builder;
}
