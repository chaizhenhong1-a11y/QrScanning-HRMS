import 'package:flutter/material.dart';

import '../../application/attendance_service.dart';
import '../../domain/attendance_settings.dart';

class AttendanceSettingsPage extends StatefulWidget {
  const AttendanceSettingsPage({super.key});

  @override
  State<AttendanceSettingsPage> createState() => _AttendanceSettingsPageState();
}

class _AttendanceSettingsPageState extends State<AttendanceSettingsPage> {
  final _service = AttendanceApplicationService();

  bool _loading = true;
  bool _saving = false;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 18, minute: 0);
  int _graceMinutes = 5;
  bool _requireQr = false;
  String _timeZone = 'Asia/Kuala_Lumpur';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _service.settings();
    if (!mounted) return;
    setState(() {
      _start = _toTime(settings.workStartMinutes);
      _end = _toTime(settings.workEndMinutes);
      _graceMinutes = settings.graceMinutes;
      _requireQr = settings.requireQr;
      _timeZone = settings.timeZone;
      _loading = false;
    });
  }

  Future<void> _pick(bool start) async {
    final value = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (value == null) return;
    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _save() async {
    if (_minutes(_end) <= _minutes(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.updateSettings(
        AttendanceSettings(
          workStartMinutes: _minutes(_start),
          workEndMinutes: _minutes(_end),
          graceMinutes: _graceMinutes,
          requireQr: _requireQr,
          timeZone: _timeZone,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance policy updated.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.login_rounded),
                  title: const Text('Work start'),
                  subtitle: Text(_start.format(context)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pick(true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Work end'),
                  subtitle: Text(_end.format(context)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pick(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Late grace period',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Slider(
                    value: _graceMinutes.toDouble(),
                    min: 0,
                    max: 30,
                    divisions: 30,
                    label: '$_graceMinutes min',
                    onChanged: (value) {
                      setState(() => _graceMinutes = value.round());
                    },
                  ),
                  Text('$_graceMinutes minutes'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: SwitchListTile(
              value: _requireQr,
              onChanged: (value) => setState(() => _requireQr = value),
              title: const Text('Require company QR'),
              subtitle: const Text(
                'When enabled, employees cannot clock directly from the app.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _timeZone,
            decoration: const InputDecoration(labelText: 'Company time zone'),
            items: const [
              DropdownMenuItem(
                value: 'Asia/Kuala_Lumpur',
                child: Text('Malaysia / Kuala Lumpur'),
              ),
              DropdownMenuItem(
                value: 'Asia/Singapore',
                child: Text('Singapore'),
              ),
              DropdownMenuItem(value: 'Asia/Bangkok', child: Text('Bangkok')),
              DropdownMenuItem(
                value: 'Asia/Ho_Chi_Minh',
                child: Text('Ho Chi Minh City'),
              ),
              DropdownMenuItem(
                value: 'Asia/Shanghai',
                child: Text('China / Shanghai'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _timeZone = value);
              }
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Text('Save attendance policy'),
          ),
        ],
      ),
    );
  }

  static int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;

  static TimeOfDay _toTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}
