import 'package:flutter/material.dart';

import '../../application/attendance_service.dart';
import '../../domain/attendance_entry.dart';
import '../../../leave/application/leave_service.dart';
import '../../../leave/domain/leave_request.dart';
import 'attendance_settings_page.dart';

class TeamAttendancePage extends StatefulWidget {
  const TeamAttendancePage({super.key});

  @override
  State<TeamAttendancePage> createState() => _TeamAttendancePageState();
}

class _TeamAttendancePageState extends State<TeamAttendancePage> {
  final _service = AttendanceApplicationService();
  DateTime _date = DateTime.now();
  late Future<Stream<List<AttendanceEntry>>> _streamFuture;
  late Future<Stream<List<LeaveRequest>>> _leaveStreamFuture;

  @override
  void initState() {
    super.initState();
    _streamFuture = _load();
    _leaveStreamFuture = _loadLeaves();
  }

  Future<Stream<List<AttendanceEntry>>> _load() =>
      _service.teamForDate(_dateKey(_date));

  Future<Stream<List<LeaveRequest>>> _loadLeaves() =>
      LeaveService().watchApprovedForDate(_dateKey(_date));

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value == null) return;
    setState(() {
      _date = value;
      _streamFuture = _load();
      _leaveStreamFuture = _loadLeaves();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Attendance'),
        actions: [
          IconButton(
            tooltip: 'Attendance policy',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AttendanceSettingsPage(),
              ),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Stream<List<AttendanceEntry>>>(
        future: _streamFuture,
        builder: (context, streamSnapshot) {
          if (!streamSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return FutureBuilder<Stream<List<LeaveRequest>>>(
            future: _leaveStreamFuture,
            builder: (context, leaveStreamSnapshot) {
              if (!leaveStreamSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<List<AttendanceEntry>>(
                stream: streamSnapshot.data!,
                builder: (context, snapshot) {
                  final entries = snapshot.data ?? const <AttendanceEntry>[];

                  return StreamBuilder<List<LeaveRequest>>(
                    stream: leaveStreamSnapshot.data!,
                    builder: (context, leaveSnapshot) {
                      final leaves =
                          leaveSnapshot.data ?? const <LeaveRequest>[];
                      final late = entries
                          .where((entry) => entry.isLate)
                          .length;
                      final completed = entries
                          .where((entry) => entry.isCompleted)
                          .length;
                      final presentEmployeeIds = entries
                          .map((entry) => entry.employeeId)
                          .toSet();
                      final leaveOnly = leaves
                          .where(
                            (leave) =>
                                !presentEmployeeIds.contains(leave.employeeId),
                          )
                          .toList();

                      return ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.calendar_month_rounded),
                              title: Text(_dateKey(_date)),
                              subtitle: Text(
                                '${entries.length} present • ${leaveOnly.length} on leave • '
                                '$late late • $completed completed',
                              ),
                              trailing: const Icon(Icons.edit_calendar_rounded),
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (entries.isEmpty && leaveOnly.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 90),
                              child: Center(
                                child: Text(
                                  'No attendance or approved leave for this date.',
                                ),
                              ),
                            )
                          else ...[
                            ...leaveOnly.map(
                              (leave) => Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.beach_access_rounded),
                                  ),
                                  title: Text(leave.employeeName),
                                  subtitle: Text(
                                    '${leave.employeeId}'
                                    '${leave.department.isEmpty ? '' : ' • ${leave.department}'}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'On Leave',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        leave.typeName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ...entries.map(
                              (entry) => Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      entry.employeeName.isEmpty
                                          ? '?'
                                          : entry.employeeName[0].toUpperCase(),
                                    ),
                                  ),
                                  title: Text(entry.employeeName),
                                  subtitle: Text(
                                    '${entry.employeeId}'
                                    '${entry.department.isEmpty ? '' : ' • ${entry.department}'}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${_time(entry.clockInAt)} → '
                                        '${_time(entry.clockOutAt)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        entry.isLate
                                            ? 'Late'
                                            : entry.leftEarly
                                            ? 'Early leave'
                                            : entry.isCompleted
                                            ? 'Completed'
                                            : 'In progress',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _time(DateTime? value) {
    if (value == null) return '--:--';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
