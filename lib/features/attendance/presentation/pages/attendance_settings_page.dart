import 'package:flutter/material.dart';

import '../../../../core/utils/firebase_error_message.dart';
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
  String? _loadError;

  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 18, minute: 0);
  int _graceMinutes = 5;
  bool _requireQr = false;
  String _timeZone = 'Asia/Kuala_Lumpur';

  AttendanceSettings? _savedSettings;

  bool get _dirty {
    final saved = _savedSettings;
    if (saved == null) return false;
    return saved.workStartMinutes != _minutes(_start) ||
        saved.workEndMinutes != _minutes(_end) ||
        saved.graceMinutes != _graceMinutes ||
        saved.requireQr != _requireQr ||
        saved.timeZone != _timeZone;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final settings = await _service.settings();
      if (!mounted) return;
      setState(() {
        _applySettings(settings);
        _savedSettings = settings;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = firebaseErrorMessage(error);
      });
    }
  }

  void _applySettings(AttendanceSettings settings) {
    _start = _toTime(settings.workStartMinutes);
    _end = _toTime(settings.workEndMinutes);
    _graceMinutes = settings.graceMinutes.clamp(0, 30);
    _requireQr = settings.requireQr;
    _timeZone = _supportedTimeZones.contains(settings.timeZone)
        ? settings.timeZone
        : 'Asia/Kuala_Lumpur';
  }

  Future<void> _pick(bool start) async {
    if (_saving) return;
    final value = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (value == null || !mounted) return;

    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_minutes(_end) <= _minutes(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    if (!_supportedTimeZones.contains(_timeZone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a supported company time zone.')),
      );
      return;
    }

    if (!_dirty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance policy changes to save.')),
      );
      return;
    }

    final settings = AttendanceSettings(
      workStartMinutes: _minutes(_start),
      workEndMinutes: _minutes(_end),
      graceMinutes: _graceMinutes,
      requireQr: _requireQr,
      timeZone: _timeZone,
    );

    setState(() => _saving = true);
    try {
      await _service.updateSettings(settings);
      if (!mounted) return;
      setState(() => _savedSettings = settings);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance policy updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty || _saving) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'Your attendance policy has unsaved changes. Leave without saving them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Policy')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(height: 16),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF475569)),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving || !_dirty) return;
        final navigator = Navigator.of(context);
        final discard = await _confirmDiscard();
        if (discard && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance Policy'),
          actions: [
            if (_dirty)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    'Unsaved',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    enabled: !_saving,
                    leading: const Icon(Icons.login_rounded),
                    title: const Text('Work start'),
                    subtitle: Text(_start.format(context)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _pick(true),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    enabled: !_saving,
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
                      onChanged: _saving
                          ? null
                          : (value) {
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
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _requireQr = value),
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
              onChanged: _saving
                  ? null
                  : (value) {
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
      ),
    );
  }

  static int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;

  static TimeOfDay _toTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  static const _supportedTimeZones = <String>{
    'Asia/Kuala_Lumpur',
    'Asia/Singapore',
    'Asia/Bangkok',
    'Asia/Ho_Chi_Minh',
    'Asia/Shanghai',
  };
}
