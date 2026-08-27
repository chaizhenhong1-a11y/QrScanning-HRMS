import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/leave_service.dart';
import '../../domain/leave_balance.dart';
import '../../domain/leave_policy.dart';
import '../../domain/leave_request.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final _service = LeaveService();
  final _reasonController = TextEditingController();

  late Future<_LeavePageData> _future;
  DateTime? _startDate;
  DateTime? _endDate;
  LeaveDuration _duration = LeaveDuration.fullDay;
  String? _typeId;
  XFile? _attachment;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<_LeavePageData> _load() async {
    final values = await Future.wait<dynamic>([
      _service.policy(),
      _service.overview(),
      _service.loadMine(),
    ]);
    final policy = values[0] as LeavePolicy;
    if (_typeId == null && policy.types.isNotEmpty) {
      _typeId = policy.types.first.id;
    }
    return _LeavePageData(
      policy: policy,
      overview: values[1] as LeaveOverview,
      requests: values[2] as List<LeaveRequest>,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start
          ? (_startDate ?? now)
          : (_endDate ?? _startDate ?? now),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate == null || _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }

      if (_duration != LeaveDuration.fullDay) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickAttachment() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (file != null && mounted) {
      setState(() => _attachment = file);
    }
  }

  Future<void> _submit(_LeavePageData data) async {
    if (_typeId == null ||
        _startDate == null ||
        _endDate == null ||
        _reasonController.text.trim().isEmpty) {
      _notice('Complete the leave type, dates and reason.');
      return;
    }

    if (_startDate!.year != _endDate!.year) {
      _notice('A leave request cannot cross into another calendar year.');
      return;
    }

    final type = data.policy.byId(_typeId!);
    if (type == null) {
      _notice('Choose a valid leave type.');
      return;
    }

    if (type.requiresAttachment && _attachment == null) {
      _notice('${type.name} requires a supporting attachment.');
      return;
    }

    setState(() => _submitting = true);
    String? uploadedPath;

    try {
      if (_attachment != null) {
        uploadedPath = await _service.uploadAttachment(_attachment!);
      }

      await _service.submit(
        typeId: type.id,
        startDate: _startDate!,
        endDate: _endDate!,
        duration: _duration,
        reason: _reasonController.text,
        attachmentPath: uploadedPath,
      );

      if (!mounted) return;
      _reasonController.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
        _duration = LeaveDuration.fullDay;
        _attachment = null;
      });
      await _reload();
      if (mounted) _notice('Leave request submitted for approval.');
    } catch (error) {
      if (uploadedPath != null) {
        await _service.deleteAttachment(uploadedPath);
      }
      if (!mounted) return;
      _notice(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(LeaveRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel leave request?'),
        content: const Text(
          'The reserved leave balance will be released immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.cancel(request);
      await _reload();
      if (mounted) _notice('Leave request cancelled.');
    } catch (error) {
      if (mounted) _notice(_friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave')),
      body: FutureBuilder<_LeavePageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Unable to load leave data.'));
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              children: [
                _BalanceSection(overview: data.overview),
                const SizedBox(height: 22),
                Text(
                  'New request',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _typeId,
                          decoration: const InputDecoration(
                            labelText: 'Leave type',
                          ),
                          items: data.policy.types
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type.id,
                                  child: Text(type.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _submitting
                              ? null
                              : (value) => setState(() => _typeId = value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<LeaveDuration>(
                          initialValue: _duration,
                          decoration: const InputDecoration(
                            labelText: 'Duration',
                          ),
                          items: LeaveDuration.values
                              .map(
                                (duration) => DropdownMenuItem(
                                  value: duration,
                                  child: Text(duration.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _submitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _duration = value;
                                    if (value != LeaveDuration.fullDay) {
                                      _endDate = _startDate;
                                    }
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _submitting
                                    ? null
                                    : () => _pickDate(true),
                                icon: const Icon(Icons.event_rounded),
                                label: Text(_fmt(_startDate) ?? 'Start date'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _submitting ||
                                        _duration != LeaveDuration.fullDay
                                    ? null
                                    : () => _pickDate(false),
                                icon: const Icon(Icons.event_available_rounded),
                                label: Text(_fmt(_endDate) ?? 'End date'),
                              ),
                            ),
                          ],
                        ),
                        if (_startDate != null && _endDate != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Estimated: ${_estimateDays()} day(s)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: _reasonController,
                          enabled: !_submitting,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Reason',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _submitting ? null : _pickAttachment,
                          icon: const Icon(Icons.attach_file_rounded),
                          label: Text(
                            _attachment?.name ?? 'Attach supporting image',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting ? null : () => _submit(data),
                            child: Text(
                              _submitting ? 'Submitting…' : 'Submit request',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'My requests',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (data.requests.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No leave requests yet.'),
                    ),
                  )
                else
                  ...data.requests.map(
                    (request) => _RequestCard(
                      request: request,
                      onCancel: request.status == LeaveRequestStatus.pending
                          ? () => _cancel(request)
                          : null,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _estimateDays() {
    if (_startDate == null || _endDate == null) return 0;
    if (_duration != LeaveDuration.fullDay) return 0.5;

    var cursor = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
    var days = 0.0;

    while (!cursor.isAfter(end)) {
      if (cursor.weekday <= DateTime.friday) days++;
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _friendlyError(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');

  static String? _fmt(DateTime? value) => value == null
      ? null
      : '${value.year}-${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';
}

class _LeavePageData {
  const _LeavePageData({
    required this.policy,
    required this.overview,
    required this.requests,
  });

  final LeavePolicy policy;
  final LeaveOverview overview;
  final List<LeaveRequest> requests;
}

class _BalanceSection extends StatelessWidget {
  const _BalanceSection({required this.overview});

  final LeaveOverview overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${overview.year} Leave Balance',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: overview.balances.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = overview.balances[index];
              return Container(
                width: 160,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.typeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      item.hasQuota
                          ? '${item.remaining!.toStringAsFixed(item.remaining! % 1 == 0 ? 0 : 1)} days'
                          : 'No quota',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      item.hasQuota
                          ? '${item.used.g} used · ${item.reserved.g} pending'
                          : 'Balance not deducted',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

extension on double {
  String get g => toStringAsFixed(this % 1 == 0 ? 0 : 1);
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onCancel});

  final LeaveRequest request;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.typeName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(
                  label: Text(request.status.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              '${request.startDateKey} → ${request.endDateKey} · '
              '${request.daysRequested.g} day(s)',
            ),
            const SizedBox(height: 6),
            Text(request.reason),
            if (request.attachmentPath?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.attachment_rounded, size: 16),
                  SizedBox(width: 5),
                  Text('Supporting attachment uploaded'),
                ],
              ),
            ],
            if (request.reviewNote?.isNotEmpty == true) ...[
              const Divider(height: 24),
              Text('Review note: ${request.reviewNote}'),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
