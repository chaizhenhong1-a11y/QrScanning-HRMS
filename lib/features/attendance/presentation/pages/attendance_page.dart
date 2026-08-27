import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';

import '../../../../screens/employee_scan_screen.dart';
import '../../application/attendance_service.dart';
import '../../domain/attendance_entry.dart';
import '../../domain/attendance_settings.dart';
import '../../../leave/application/leave_service.dart';
import '../../../leave/domain/leave_request.dart';
import 'attendance_history_page.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _service = AttendanceApplicationService();

  late Future<_AttendanceViewData> _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AttendanceViewData> _load() async {
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final values = await Future.wait<dynamic>([
      _service.settings(),
      _service.today(),
      LeaveService().approvedForDate(dateKey),
    ]);

    return _AttendanceViewData(
      settings: values[0] as AttendanceSettings,
      today: values[1] as AttendanceEntry?,
      leaveToday: values[2] as LeaveRequest?,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _clock() async {
    setState(() => _submitting = true);
    try {
      final result = await _service.clockFromApp();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _scanQr() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EmployeeScanScreen()));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AttendanceHistoryPage(),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_AttendanceViewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Unable to load attendance.'));
          }

          final data = snapshot.data!;
          final today = data.today;
          final settings = data.settings;
          final nextAction = data.leaveToday != null
              ? 'On Leave'
              : today == null || !today.hasClockedIn
              ? 'Clock In'
              : today.hasClockedOut
              ? 'Completed'
              : 'Clock Out';

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: VeyraDesign.brandGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${settings.workStartLabel} – ${settings.workEndLabel}'
                        '  •  ${settings.graceMinutes} min grace',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeBox(
                              label: 'Clock In',
                              value: _time(today?.clockInAt),
                              status: _status(today?.clockInStatus),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TimeBox(
                              label: 'Clock Out',
                              value: _time(today?.clockOutAt),
                              status: _status(today?.clockOutStatus),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          data.leaveToday != null
                              ? 'Approved leave today'
                              : settings.requireQr
                              ? 'Company QR required'
                              : 'Mobile attendance enabled',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data.leaveToday != null
                              ? '${data.leaveToday!.typeName} · '
                                    '${data.leaveToday!.daysRequested} day(s). '
                                    'Attendance clocking is disabled for this approved leave.'
                              : settings.requireQr
                              ? 'Scan the latest company QR code to record attendance.'
                              : 'You can clock directly here or use the company QR code.',
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed:
                              _submitting ||
                                  data.leaveToday != null ||
                                  settings.requireQr ||
                                  nextAction == 'Completed'
                              ? null
                              : _clock,
                          icon: Icon(
                            nextAction == 'Clock Out'
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                          ),
                          label: Text(nextAction),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _submitting || data.leaveToday != null
                              ? null
                              : _scanQr,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Scan company QR'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (today?.workedMinutes != null) ...[
                  const SizedBox(height: 18),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.schedule_rounded),
                      ),
                      title: const Text('Worked today'),
                      subtitle: Text(_duration(today!.workedMinutes!)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static String _time(DateTime? value) {
    if (value == null) return '--:--';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String _status(String? value) => switch (value) {
    'late' => 'Late',
    'onTime' => 'On time',
    'early' => 'Early',
    'normal' => 'Normal',
    _ => '',
  };

  static String _duration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }
}

class _AttendanceViewData {
  const _AttendanceViewData({
    required this.settings,
    required this.today,
    required this.leaveToday,
  });

  final AttendanceSettings settings;
  final AttendanceEntry? today;
  final LeaveRequest? leaveToday;
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final String value;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (status.isNotEmpty)
            Text(status, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
