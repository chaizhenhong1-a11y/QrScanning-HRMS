import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../../../core/utils/firebase_error_message.dart';
import '../../application/flexible_work_service.dart';
import '../../domain/flexible_work_request.dart';

class FlexibleWorkPage extends StatefulWidget {
  const FlexibleWorkPage({super.key});

  @override
  State<FlexibleWorkPage> createState() => _FlexibleWorkPageState();
}

class _FlexibleWorkPageState extends State<FlexibleWorkPage> {
  final _service = FlexibleWorkService();
  late Future<FlexibleWorkSession> _sessionFuture;
  bool _busy = false;
  int _viewMode = 0;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _service.session();
  }

  Future<void> _reload() async {
    setState(() => _sessionFuture = _service.session());
    await _sessionFuture;
  }

  Future<void> _submit(FlexibleWorkSession session) async {
    final formKey = GlobalKey<FormState>();
    final location = TextEditingController();
    final reason = TextEditingController();
    var type = FlexibleWorkType.workFromHome;
    var startDate = DateTime.now();
    var endDate = DateTime.now();
    var startTime = const TimeOfDay(hour: 9, minute: 0);
    var endTime = const TimeOfDay(hour: 18, minute: 0);
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> save() async {
            if (saving || !(formKey.currentState?.validate() ?? false)) return;
            setDialogState(() => saving = true);
            setState(() => _busy = true);
            try {
              await _service.submit(
                session: session,
                type: type,
                startDate: startDate,
                endDate: endDate,
                startMinutes: startTime.hour * 60 + startTime.minute,
                endMinutes: endTime.hour * 60 + endTime.minute,
                workLocation: location.text,
                reason: reason.text,
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            } catch (error) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(firebaseErrorMessage(error))),
                );
                setDialogState(() => saving = false);
              }
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          }

          Future<DateTime?> pickDate(DateTime initial) => showDatePicker(
            context: dialogContext,
            initialDate: initial,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );

          return AlertDialog(
            title: const Text('Flexible work request'),
            content: SizedBox(
              width: 560,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<FlexibleWorkType>(
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Arrangement',
                        ),
                        items: FlexibleWorkType.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() => type = value);
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start date'),
                        subtitle: Text(_date(startDate)),
                        trailing: const Icon(Icons.calendar_month_rounded),
                        onTap: saving
                            ? null
                            : () async {
                                final value = await pickDate(startDate);
                                if (value != null && dialogContext.mounted) {
                                  setDialogState(() {
                                    startDate = value;
                                    if (endDate.isBefore(value)) {
                                      endDate = value;
                                    }
                                  });
                                }
                              },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('End date'),
                        subtitle: Text(_date(endDate)),
                        trailing: const Icon(Icons.calendar_month_rounded),
                        onTap: saving
                            ? null
                            : () async {
                                final value = await pickDate(endDate);
                                if (value != null && dialogContext.mounted) {
                                  setDialogState(() => endDate = value);
                                }
                              },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Start time'),
                              subtitle: Text(startTime.format(dialogContext)),
                              onTap: saving
                                  ? null
                                  : () async {
                                      final value = await showTimePicker(
                                        context: dialogContext,
                                        initialTime: startTime,
                                      );
                                      if (value != null &&
                                          dialogContext.mounted) {
                                        setDialogState(() => startTime = value);
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('End time'),
                              subtitle: Text(endTime.format(dialogContext)),
                              onTap: saving
                                  ? null
                                  : () async {
                                      final value = await showTimePicker(
                                        context: dialogContext,
                                        initialTime: endTime,
                                      );
                                      if (value != null &&
                                          dialogContext.mounted) {
                                        setDialogState(() => endTime = value);
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: location,
                        enabled: !saving,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'Work location',
                          hintText: 'Home, client site, coworking space...',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: reason,
                        enabled: !saving,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 1000,
                        decoration: const InputDecoration(labelText: 'Reason'),
                        validator: (value) => (value?.trim().length ?? 0) < 5
                            ? 'Enter at least 5 characters.'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
    location.dispose();
    reason.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flexible work request submitted.')),
      );
    }
  }

  Future<void> _review(
    FlexibleWorkSession session,
    FlexibleWorkRequest request,
  ) async {
    final note = TextEditingController();
    final decision = await showDialog<FlexibleWorkStatus>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Review ${request.employeeName}'),
        content: TextField(
          controller: note,
          maxLength: 1000,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Review note (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, FlexibleWorkStatus.rejected),
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, FlexibleWorkStatus.approved),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    final reviewNote = note.text;
    note.dispose();
    if (decision == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.review(
        session: session,
        request: request,
        status: decision,
        note: reviewNote,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(firebaseErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(
    FlexibleWorkSession session,
    FlexibleWorkRequest request,
  ) async {
    setState(() => _busy = true);
    try {
      await _service.withdraw(session: session, request: request);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(firebaseErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FlexibleWorkSession>(
      future: _sessionFuture,
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (sessionSnapshot.hasError || !sessionSnapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Flexible Work')),
            body: Center(
              child: Text(
                firebaseErrorMessage(
                  sessionSnapshot.error ?? StateError('Session unavailable.'),
                ),
              ),
            ),
          );
        }
        final session = sessionSnapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Flexible Work'),
            actions: [
              IconButton(
                tooltip: 'New request',
                onPressed: _busy ? null : () => _submit(session),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: DecoratedBox(
            decoration: VeyraDesign.pageBackground,
            child: Column(
              children: [
                if (session.canApprove)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          label: Text('My Requests'),
                          icon: Icon(Icons.person_outline),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('Pending'),
                          icon: Icon(Icons.approval_outlined),
                        ),
                        ButtonSegment(
                          value: 2,
                          label: Text('History'),
                          icon: Icon(Icons.history_rounded),
                        ),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (value) {
                        setState(() => _viewMode = value.first);
                      },
                    ),
                  ),
                Expanded(
                  child: StreamBuilder<List<FlexibleWorkRequest>>(
                    stream: switch (_viewMode) {
                      1 when session.canApprove => _service.watchForApproval(
                        session,
                      ),
                      2 when session.canApprove =>
                        _service.watchApprovalHistory(session),
                      _ => _service.watchMine(session),
                    },
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(firebaseErrorMessage(snapshot.error!)),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items = snapshot.data!.where((item) {
                        if (_viewMode == 1 && session.canApprove) {
                          return item.status == FlexibleWorkStatus.pending &&
                              item.uid != session.uid;
                        }
                        if (_viewMode == 2 && session.canApprove) {
                          return (item.status == FlexibleWorkStatus.approved ||
                                  item.status == FlexibleWorkStatus.rejected) &&
                              item.reviewerUid == session.uid;
                        }
                        return item.uid == session.uid;
                      }).toList();
                      if (items.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.home_work_outlined,
                                  size: 54,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _viewMode == 1
                                      ? 'No pending approvals'
                                      : _viewMode == 2
                                      ? 'No approval history'
                                      : 'No flexible work requests',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                                if (_viewMode == 0) ...[
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _submit(session),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('New request'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(18),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[index];
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
                                            _viewMode == 0
                                                ? item.type.label
                                                : item.employeeName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Chip(label: Text(item.status.label)),
                                      ],
                                    ),
                                    if (_viewMode != 0) Text(item.type.label),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_date(item.startDate)} → ${_date(item.endDate)}',
                                    ),
                                    Text(
                                      '${_time(item.startMinutes)} → ${_time(item.endMinutes)}',
                                    ),
                                    if (item.workLocation.isNotEmpty)
                                      Text('Location: ${item.workLocation}'),
                                    const SizedBox(height: 8),
                                    Text(item.reason),
                                    if (item.reviewNote?.isNotEmpty ==
                                        true) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Review: ${item.reviewNote}',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                    if (_viewMode == 2) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Reviewed by: ${item.reviewerName ?? 'Reviewer'}',
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      if (item.reviewedAt != null)
                                        Text(
                                          'Reviewed at: ${_dateTime(item.reviewedAt!)}',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                    ],
                                    if (_viewMode == 1 &&
                                        item.status ==
                                            FlexibleWorkStatus.pending) ...[
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: FilledButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _review(session, item),
                                          child: const Text('Review'),
                                        ),
                                      ),
                                    ] else if (item.uid == session.uid &&
                                        item.status ==
                                            FlexibleWorkStatus.pending) ...[
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _withdraw(session, item),
                                          child: const Text('Withdraw'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  static String _dateTime(DateTime value) {
    final local = value.toLocal();
    return '${_date(local)} ${_time(local.hour * 60 + local.minute)}';
  }
}
