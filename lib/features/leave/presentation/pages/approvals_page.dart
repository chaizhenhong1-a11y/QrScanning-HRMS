import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../../claims/application/claim_service.dart';
import '../../../claims/domain/claim_request.dart';
import '../../application/leave_service.dart';
import '../../domain/leave_request.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage>
    with SingleTickerProviderStateMixin {
  final _leaveService = LeaveService();
  final _claimService = ClaimService();

  late final TabController _tabs;
  late Future<Stream<List<LeaveRequest>>> _leaveStreamFuture;
  late Future<Stream<List<ClaimRequest>>> _claimStreamFuture;

  String? _reviewingLeaveId;
  String? _reviewingClaimId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _leaveStreamFuture = _leaveService.watchForApproval();
    _claimStreamFuture = _claimService.watchForApproval();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refreshLeaves() async {
    setState(() {
      _leaveStreamFuture = _leaveService.watchForApproval();
    });
    await _leaveStreamFuture;
  }

  Future<void> _refreshClaims() async {
    setState(() {
      _claimStreamFuture = _claimService.watchForApproval();
    });
    await _claimStreamFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Leave'),
            Tab(text: 'Claims'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [_leaveTab(), _claimTab()]),
    );
  }

  Widget _leaveTab() {
    return FutureBuilder<Stream<List<LeaveRequest>>>(
      future: _leaveStreamFuture,
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<List<LeaveRequest>>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _error(
                'Unable to refresh leave approvals.',
                _refreshLeaves,
              );
            }
            final items = snapshot.data ?? const <LeaveRequest>[];
            if (items.isEmpty) {
              return _empty('No pending leave requests.', _refreshLeaves);
            }

            return RefreshIndicator(
              onRefresh: _refreshLeaves,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final request = items[index];
                  final busy = _reviewingLeaveId == request.id;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _employeeHeader(
                            request.employeeName,
                            '${request.employeeId} · ${request.department}',
                            request.status.label,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            request.typeName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${request.startDateKey} → ${request.endDateKey} · '
                            '${_days(request.daysRequested)} day(s)',
                          ),
                          const SizedBox(height: 6),
                          Text(request.reason),
                          const SizedBox(height: 14),
                          busy
                              ? _progress()
                              : _decisionButtons(
                                  reject: () => _reviewLeave(
                                    request,
                                    LeaveRequestStatus.rejected,
                                  ),
                                  approve: () => _reviewLeave(
                                    request,
                                    LeaveRequestStatus.approved,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _claimTab() {
    return FutureBuilder<Stream<List<ClaimRequest>>>(
      future: _claimStreamFuture,
      builder: (context, streamSnapshot) {
        if (!streamSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<List<ClaimRequest>>(
          stream: streamSnapshot.data!,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _error(
                'Unable to refresh claim approvals.',
                _refreshClaims,
              );
            }
            final items = snapshot.data ?? const <ClaimRequest>[];
            if (items.isEmpty) {
              return _empty('No pending expense claims.', _refreshClaims);
            }

            return RefreshIndicator(
              onRefresh: _refreshClaims,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final request = items[index];
                  final busy = _reviewingClaimId == request.id;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _employeeHeader(
                            request.employeeName,
                            '${request.employeeId} · ${request.department}',
                            request.status.label,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            request.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${request.category} · '
                            '${_date(request.expenseDate)}',
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'RM ${request.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (request.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(request.description),
                          ],
                          if (request.receiptPath?.isNotEmpty == true)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.attachment_rounded, size: 17),
                                  SizedBox(width: 5),
                                  Text('Receipt uploaded'),
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),
                          busy
                              ? _progress()
                              : _decisionButtons(
                                  reject: () => _reviewClaim(
                                    request,
                                    ClaimStatus.rejected,
                                  ),
                                  approve: () => _reviewClaim(
                                    request,
                                    ClaimStatus.approved,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _employeeHeader(String name, String subtitle, String status) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: VeyraDesign.softBrand,
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(subtitle, style: const TextStyle(color: VeyraDesign.muted)),
            ],
          ),
        ),
        Chip(label: Text(status)),
      ],
    );
  }

  Widget _decisionButtons({
    required VoidCallback reject,
    required VoidCallback approve,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(onPressed: reject, child: const Text('Reject')),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(onPressed: approve, child: const Text('Approve')),
        ),
      ],
    );
  }

  Widget _progress() {
    return const SizedBox(
      height: 44,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            SizedBox(width: 10),
            Text('Updating request…'),
          ],
        ),
      ),
    );
  }

  Widget _empty(String message, Future<void> Function() refresh) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * .25),
          const Icon(Icons.inbox_outlined, size: 56, color: VeyraDesign.muted),
          const SizedBox(height: 12),
          Center(child: Text(message)),
        ],
      ),
    );
  }

  Widget _error(String message, Future<void> Function() retry) {
    return Center(
      child: FilledButton.icon(
        onPressed: retry,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(message),
      ),
    );
  }

  Future<String?> _reviewNote(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Review note (optional)',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _reviewLeave(
    LeaveRequest request,
    LeaveRequestStatus status,
  ) async {
    if (_reviewingLeaveId != null) return;
    final note = await _reviewNote('${status.label} leave request?');
    if (note == null || !mounted) return;
    setState(() => _reviewingLeaveId = request.id);
    try {
      await _leaveService.review(request: request, status: status, note: note);
      if (mounted) _notice('Leave request ${status.label.toLowerCase()}.');
    } catch (error) {
      if (mounted) _notice(_friendly(error));
    } finally {
      if (mounted) setState(() => _reviewingLeaveId = null);
    }
  }

  Future<void> _reviewClaim(ClaimRequest request, ClaimStatus status) async {
    if (_reviewingClaimId != null) return;
    final note = await _reviewNote('${status.label} expense claim?');
    if (note == null || !mounted) return;
    setState(() => _reviewingClaimId = request.id);
    try {
      await _claimService.review(request: request, status: status, note: note);
      if (mounted) _notice('Claim ${status.label.toLowerCase()}.');
    } catch (error) {
      if (mounted) _notice(_friendly(error));
    } finally {
      if (mounted) setState(() => _reviewingClaimId = null);
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _friendly(Object error) => error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');

  static String _days(double value) =>
      value.toStringAsFixed(value % 1 == 0 ? 0 : 1);

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
