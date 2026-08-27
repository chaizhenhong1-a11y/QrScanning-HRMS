import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../../../core/utils/firebase_error_message.dart';
import '../../application/audit_service.dart';
import '../../domain/audit_log_entry.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  final _service = AuditService();
  late Future<List<AuditLogEntry>> _future;

  String? _module;
  String? _action;
  bool _refreshing = false;
  final _actorController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  static const _modules = <String>[
    'attendance',
    'leave',
    'claims',
    'payroll',
    'employee',
    'asset',
    'lifecycle',
    'performance',
    'documents',
    'workforce',
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _actorController.dispose();
    super.dispose();
  }

  Future<List<AuditLogEntry>> _load() => _service.load(
    module: _module,
    action: _action,
    actorEmployeeId: _actorController.text.trim().isEmpty
        ? null
        : _actorController.text.trim(),
    startDateKey: _startDate == null ? null : _dateKey(_startDate!),
    endDateKey: _endDate == null ? null : _dateKey(_endDate!),
  );

  Future<void> _reload() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final next = _load();
      if (mounted) setState(() => _future = next);
      await next;
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: _filters,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<AuditLogEntry>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 180),
                    Center(
                      child: Text(
                        firebaseErrorMessage(snapshot.error!),
                        textAlign: TextAlign.center,
                      ),
                    ),
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

              final entries = snapshot.data ?? const <AuditLogEntry>[];
              if (entries.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Icon(
                      Icons.history_rounded,
                      size: 54,
                      color: VeyraDesign.muted,
                    ),
                    SizedBox(height: 12),
                    Center(child: Text('No audit activity found.')),
                  ],
                );
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final item = entries[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: VeyraDesign.primary.withValues(
                              alpha: .12,
                            ),
                            child: Icon(
                              _icon(item.module),
                              color: VeyraDesign.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _label(item.action),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(item.module.toUpperCase()),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(item.summary),
                                const SizedBox(height: 8),
                                Text(
                                  '${item.actorName} (${item.actorEmployeeId})',
                                  style: const TextStyle(
                                    color: VeyraDesign.muted,
                                  ),
                                ),
                                if (item.targetId.isNotEmpty)
                                  Text(
                                    '${item.targetType}: ${item.targetId}',
                                    style: const TextStyle(
                                      color: VeyraDesign.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (item.createdAt != null)
                                  Text(
                                    _time(item.createdAt!),
                                    style: const TextStyle(
                                      color: VeyraDesign.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _filters() async {
    String? module = _module;
    String? action = _action;
    DateTime? start = _startDate;
    DateTime? end = _endDate;

    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Audit filters'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: module,
                  decoration: const InputDecoration(labelText: 'Module'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All modules'),
                    ),
                    ..._modules.map(
                      (value) => DropdownMenuItem<String?>(
                        value: value,
                        child: Text(value),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => module = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _actorController,
                  decoration: const InputDecoration(
                    labelText: 'Actor employee ID',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(labelText: 'Action'),
                  onChanged: (value) =>
                      action = value.trim().isEmpty ? null : value.trim(),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          start ??
                          DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => start = picked);
                  },
                  icon: const Icon(Icons.event_rounded),
                  label: Text(start == null ? 'Start date' : _dateKey(start!)),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: end ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => end = picked);
                  },
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(end == null ? 'End date' : _dateKey(end!)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setDialogState(() {
                  module = null;
                  action = null;
                  start = null;
                  end = null;
                  _actorController.clear();
                });
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (apply == true) {
      setState(() {
        _module = module;
        _action = action;
        _startDate = start;
        _endDate = end;
        _future = _load();
      });
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _time(DateTime value) {
    final local = value.toLocal();
    return '${_dateKey(local)} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String _label(String value) =>
      value.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}');

  static IconData _icon(String module) => switch (module) {
    'attendance' => Icons.schedule_rounded,
    'leave' => Icons.beach_access_rounded,
    'claims' => Icons.receipt_long_rounded,
    'payroll' => Icons.payments_rounded,
    'employee' => Icons.badge_rounded,
    'asset' => Icons.inventory_2_rounded,
    'lifecycle' => Icons.route_rounded,
    'performance' => Icons.insights_rounded,
    'documents' => Icons.folder_copy_rounded,
    'workforce' => Icons.more_time_rounded,
    _ => Icons.history_rounded,
  };
}
