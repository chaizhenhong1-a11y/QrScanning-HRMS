import 'package:flutter/material.dart';

import '../../application/attendance_service.dart';
import '../../domain/attendance_entry.dart';

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final _service = AttendanceApplicationService();
  late Future<List<AttendanceEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.history();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.history();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: FutureBuilder<List<AttendanceEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? const <AttendanceEntry>[];
          if (entries.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Icon(Icons.event_note_rounded, size: 54, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(child: Text('No Firestore attendance records yet')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.dateKey,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _StateChip(entry),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _HistoryTime(
                                label: 'Clock In',
                                value: _time(entry.clockInAt),
                              ),
                            ),
                            Expanded(
                              child: _HistoryTime(
                                label: 'Clock Out',
                                value: _time(entry.clockOutAt),
                              ),
                            ),
                            Expanded(
                              child: _HistoryTime(
                                label: 'Worked',
                                value: entry.workedMinutes == null
                                    ? '--'
                                    : _duration(entry.workedMinutes!),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
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

  static String _duration(int value) =>
      '${value ~/ 60}h ${(value % 60).toString().padLeft(2, '0')}m';
}

class _StateChip extends StatelessWidget {
  const _StateChip(this.entry);

  final AttendanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final label = entry.isLate
        ? 'Late'
        : entry.leftEarly
        ? 'Early leave'
        : entry.isCompleted
        ? 'Completed'
        : 'In progress';

    return Chip(label: Text(label));
  }
}

class _HistoryTime extends StatelessWidget {
  const _HistoryTime({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
