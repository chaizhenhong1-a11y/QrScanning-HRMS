import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../../identity/domain/hrms_role.dart';
import '../../../../core/storage/session_store.dart';
import '../../application/workforce_time_service.dart';
import '../../domain/workforce_time_models.dart';

class WorkforceTimePage extends StatefulWidget {
  const WorkforceTimePage({super.key});

  @override
  State<WorkforceTimePage> createState() => _WorkforceTimePageState();
}

class _WorkforceTimePageState extends State<WorkforceTimePage>
    with SingleTickerProviderStateMixin {
  final _service = WorkforceTimeService();
  late final TabController _tabs;
  late String _month;
  late Future<_Data> _future;
  HrmsRole _role = HrmsRole.employee;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _future = _load();
    SessionStore.getHrmsRole().then((value) {
      if (mounted) setState(() => _role = HrmsRole.fromValue(value));
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<_Data> _load() async {
    final data = await _service.overview(_month);
    return _Data(
      holidays: data.holidays,
      shifts: data.shifts,
      overtime: data.overtime,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Holiday, Shift & Overtime'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Holidays'),
            Tab(text: 'Shifts'),
            Tab(text: 'Overtime'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _month,
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: FutureBuilder<_Data>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) {
                return Center(
                  child: FilledButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return TabBarView(
              controller: _tabs,
              children: [
                _holidays(data.holidays),
                _shifts(data.shifts),
                _overtime(data.overtime),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addForCurrentTab,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _holidays(List<CompanyHoliday> items) => _list(
    items.isEmpty,
    'No company holidays in $_month.',
    items
        .map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.celebration_rounded),
              ),
              title: Text(item.name),
              subtitle: Text(item.dateKey),
              trailing: Chip(label: Text(item.isPaid ? 'Paid' : 'Unpaid')),
            ),
          ),
        )
        .toList(),
  );

  Widget _shifts(List<EmployeeShift> items) => _list(
    items.isEmpty,
    'No shift assignments in $_month.',
    items
        .map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.schedule_rounded)),
              title: Text(item.employeeName),
              subtitle: Text(
                '${item.dateKey} · ${item.shiftName}\n${item.timeLabel}',
              ),
            ),
          ),
        )
        .toList(),
  );

  Widget _overtime(List<OvertimeRequest> items) => _list(
    items.isEmpty,
    'No overtime requests in $_month.',
    items
        .map(
          (item) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.more_time_rounded)),
              title: Text(
                '${item.employeeName} · ${item.hours.toStringAsFixed(1)}h',
              ),
              subtitle: Text('${item.dateKey}\n${item.reason}'),
              trailing: _role.canApprove && item.status == 'pending'
                  ? PopupMenuButton<String>(
                      onSelected: (decision) => _review(item, decision),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'approved',
                          child: Text('Approve'),
                        ),
                        PopupMenuItem(value: 'rejected', child: Text('Reject')),
                      ],
                    )
                  : Chip(label: Text(item.status.toUpperCase())),
            ),
          ),
        )
        .toList(),
  );

  Widget _list(bool empty, String message, List<Widget> children) =>
      RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: empty
              ? [
                  const SizedBox(height: 150),
                  const Icon(
                    Icons.event_note_rounded,
                    size: 50,
                    color: VeyraDesign.muted,
                  ),
                  const SizedBox(height: 12),
                  Center(child: Text(message)),
                ]
              : children,
        ),
      );

  Future<void> _addForCurrentTab() async {
    if (_tabs.index == 0) {
      if (!_role.canManageCompany) {
        _notice('Only Company Owner or HR can create holidays.');
        return;
      }
      await _addHoliday();
    } else if (_tabs.index == 1) {
      if (!_role.canApprove) {
        _notice('You do not have permission to assign shifts.');
        return;
      }
      await _addShift();
    } else {
      await _addOvertime();
    }
  }

  Future<void> _addHoliday() async {
    final name = TextEditingController();
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add company holiday'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Holiday name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty || !mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked == null) return;
    date = picked;
    try {
      await _service.saveHoliday(
        dateKey: _key(date),
        name: name.text,
        isPaid: true,
      );
      await _reload();
    } catch (e) {
      _notice(_friendly(e));
    } finally {
      name.dispose();
    }
  }

  Future<void> _addShift() async {
    final employee = TextEditingController();
    final shift = TextEditingController(text: 'Standard');
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (date == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Assign shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: employee,
              decoration: const InputDecoration(labelText: 'Employee ID'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: shift,
              decoration: const InputDecoration(labelText: 'Shift name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (ok == true && employee.text.trim().isNotEmpty) {
      try {
        await _service.assignShift(
          employeeId: employee.text.trim(),
          dateKey: _key(date),
          shiftName: shift.text.trim().isEmpty ? 'Standard' : shift.text.trim(),
          startMinutes: 9 * 60,
          endMinutes: 18 * 60,
        );
        await _reload();
      } catch (e) {
        _notice(_friendly(e));
      }
    }
    employee.dispose();
    shift.dispose();
  }

  Future<void> _addOvertime() async {
    final hours = TextEditingController(text: '1');
    final reason = TextEditingController();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request overtime'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hours,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Hours'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reason,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    final value = double.tryParse(hours.text.trim());
    if (ok == true &&
        value != null &&
        value > 0 &&
        reason.text.trim().isNotEmpty) {
      try {
        await _service.submitOvertime(
          dateKey: _key(date),
          minutes: (value * 60).round(),
          reason: reason.text,
        );
        await _reload();
      } catch (e) {
        _notice(_friendly(e));
      }
    }
    hours.dispose();
    reason.dispose();
  }

  Future<void> _review(OvertimeRequest item, String decision) async {
    try {
      await _service.reviewOvertime(
        requestId: item.id,
        decision: decision,
        note: '',
      );
      await _reload();
      if (mounted) _notice('Overtime $decision.');
    } catch (e) {
      if (mounted) _notice(_friendly(e));
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse('$_month-01'),
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _month = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      _future = _load();
    });
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  static String _friendly(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');

  static String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _Data {
  const _Data({
    required this.holidays,
    required this.shifts,
    required this.overtime,
  });

  final List<CompanyHoliday> holidays;
  final List<EmployeeShift> shifts;
  final List<OvertimeRequest> overtime;
}
