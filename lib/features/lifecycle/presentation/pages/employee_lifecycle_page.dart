import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../application/employee_lifecycle_service.dart';
import '../../domain/employee_lifecycle.dart';

class EmployeeLifecyclePage extends StatefulWidget {
  const EmployeeLifecyclePage({super.key});

  @override
  State<EmployeeLifecyclePage> createState() => _EmployeeLifecyclePageState();
}

class _EmployeeLifecyclePageState extends State<EmployeeLifecyclePage> {
  final _service = EmployeeLifecycleService();
  late Future<_Overview> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Overview> _load() async {
    final data = await _service.overview();
    return _Overview(
      canManage: data.canManage,
      currentEmployeeId: data.currentEmployeeId,
      cases: data.cases,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Lifecycle')),
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: FutureBuilder<_Overview>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: FilledButton(
                  onPressed: _reload,
                  child: const Text('Retry'),
                ),
              );
            }

            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  _hero(data.cases),
                  if (data.canManage) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _startOnboarding,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Onboard'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _startOffboarding,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Offboard'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    data.canManage ? 'Lifecycle cases' : 'My lifecycle',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (data.cases.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No onboarding or offboarding cases yet.'),
                      ),
                    )
                  else
                    ...data.cases.map(
                      (item) => _caseCard(
                        item,
                        canManage: data.canManage,
                        currentEmployeeId: data.currentEmployeeId,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(List<EmployeeLifecycleCase> cases) {
    final active = cases.where((item) => item.status == 'active').length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: VeyraDesign.brandGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 27,
            backgroundColor: Colors.white24,
            child: Icon(Icons.route_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Employee Lifecycle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$active active workflow${active == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _caseCard(
    EmployeeLifecycleCase item, {
    required bool canManage,
    required String currentEmployeeId,
  }) {
    final isMine = item.employeeId == currentEmployeeId;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: VeyraDesign.primary.withValues(alpha: .12),
                  child: Icon(
                    item.type == 'onboarding'
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
                    color: VeyraDesign.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${item.employeeId} · ${_label(item.type)}',
                        style: const TextStyle(color: VeyraDesign.muted),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(_label(item.status))),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: item.progress),
            const SizedBox(height: 6),
            Text('${(item.progress * 100).round()}% checklist complete'),
            if (item.probationEndDateKey != null) ...[
              const SizedBox(height: 8),
              Text('Probation ends: ${item.probationEndDateKey}'),
            ],
            if (item.endDateKey != null) ...[
              const SizedBox(height: 8),
              Text('Last working day: ${item.endDateKey}'),
            ],
            if (item.reason?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text('Reason: ${item.reason}'),
            ],
            const Divider(height: 26),
            ...item.tasks.map(
              (task) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: task.completed,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(task.title),
                subtitle: Text(task.category),
                onChanged:
                    item.status != 'active' ||
                        (!canManage && (!isMine || !task.employeeCanComplete))
                    ? null
                    : (value) => _toggleTask(item, task, value ?? false),
              ),
            ),
            if (canManage &&
                item.status == 'active' &&
                item.tasks.isNotEmpty &&
                item.tasks.every((task) => task.completed))
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _complete(item),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(
                    item.type == 'onboarding'
                        ? 'Complete onboarding'
                        : 'Complete offboarding',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTask(
    EmployeeLifecycleCase item,
    LifecycleTask task,
    bool completed,
  ) async {
    try {
      await _service.setTaskCompleted(
        caseId: item.id,
        taskId: task.id,
        completed: completed,
      );
      await _reload();
    } catch (error) {
      if (mounted) _notice(_friendly(error));
    }
  }

  Future<void> _complete(EmployeeLifecycleCase item) async {
    try {
      await _service.completeCase(item.id);
      await _reload();
      if (mounted) _notice('${_label(item.type)} completed.');
    } catch (error) {
      if (mounted) _notice(_friendly(error));
    }
  }

  Future<void> _startOnboarding() async {
    final employee = TextEditingController();
    DateTime start = DateTime.now();
    DateTime? probation;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Start onboarding'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: employee,
                  decoration: const InputDecoration(labelText: 'Employee ID'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(start.year - 1),
                      lastDate: DateTime(start.year + 2),
                    );
                    if (value != null) setDialogState(() => start = value);
                  },
                  icon: const Icon(Icons.event_rounded),
                  label: Text('Start date: ${_dateKey(start)}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate:
                          probation ?? start.add(const Duration(days: 90)),
                      firstDate: start,
                      lastDate: DateTime(start.year + 2),
                    );
                    if (value != null) setDialogState(() => probation = value);
                  },
                  icon: const Icon(Icons.hourglass_bottom_rounded),
                  label: Text(
                    probation == null
                        ? 'Set probation end'
                        : 'Probation: ${_dateKey(probation!)}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && employee.text.trim().isNotEmpty) {
      try {
        await _service.startOnboarding(
          employeeId: employee.text.trim(),
          startDateKey: _dateKey(start),
          probationEndDateKey: probation == null ? null : _dateKey(probation!),
        );
        await _reload();
      } catch (error) {
        if (mounted) _notice(_friendly(error));
      }
    }
    employee.dispose();
  }

  Future<void> _startOffboarding() async {
    final employee = TextEditingController();
    final reason = TextEditingController();
    DateTime lastDay = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Start offboarding'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: employee,
                  decoration: const InputDecoration(labelText: 'Employee ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason / exit note',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: lastDay,
                      firstDate: DateTime(lastDay.year - 1),
                      lastDate: DateTime(lastDay.year + 2),
                    );
                    if (value != null) setDialogState(() => lastDay = value);
                  },
                  icon: const Icon(Icons.event_rounded),
                  label: Text('Last working day: ${_dateKey(lastDay)}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );

    if (ok == true &&
        employee.text.trim().isNotEmpty &&
        reason.text.trim().isNotEmpty) {
      try {
        await _service.startOffboarding(
          employeeId: employee.text.trim(),
          lastWorkingDateKey: _dateKey(lastDay),
          reason: reason.text.trim(),
        );
        await _reload();
      } catch (error) {
        if (mounted) _notice(_friendly(error));
      }
    }
    employee.dispose();
    reason.dispose();
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  static String _friendly(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _label(String value) => switch (value) {
    'onboarding' => 'Onboarding',
    'offboarding' => 'Offboarding',
    'active' => 'Active',
    'completed' => 'Completed',
    _ => value,
  };
}

class _Overview {
  const _Overview({
    required this.canManage,
    required this.currentEmployeeId,
    required this.cases,
  });

  final bool canManage;
  final String currentEmployeeId;
  final List<EmployeeLifecycleCase> cases;
}
