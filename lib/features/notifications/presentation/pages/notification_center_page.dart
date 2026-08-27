import 'package:flutter/material.dart';

import '../../../../app/theme/veyra_design.dart';
import '../../../../core/utils/firebase_error_message.dart';
import '../../../../screens/claims_screen.dart';
import '../../../../screens/leave_screen.dart';
import '../../../../screens/payslip_screen.dart';
import '../../application/notification_service.dart';
import '../../domain/hrms_notification.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final _service = NotificationService();
  late final Future<Stream<List<HrmsNotification>>> _streamFuture = _service
      .watchMine();

  bool _markingAllRead = false;

  Future<void> _markAllRead() async {
    if (_markingAllRead) {
      return;
    }

    setState(() => _markingAllRead = true);
    try {
      await _service.markAllRead();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(firebaseErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _markingAllRead = false);
      }
    }
  }

  Future<void> _openNotification(HrmsNotification item) async {
    if (!item.isRead) {
      try {
        await _service.markRead(item.id);
      } catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(firebaseErrorMessage(error))));
      }
    }

    if (!mounted) {
      return;
    }
    _openTarget(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: _markingAllRead ? null : _markAllRead,
            icon: _markingAllRead
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded, size: 18),
            label: Text(_markingAllRead ? 'Updating' : 'Read all'),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: VeyraDesign.pageBackground,
        child: FutureBuilder<Stream<List<HrmsNotification>>>(
          future: _streamFuture,
          builder: (context, streamSnapshot) {
            if (streamSnapshot.hasError) {
              return _LoadError(
                message: firebaseErrorMessage(streamSnapshot.error!),
              );
            }
            if (!streamSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<List<HrmsNotification>>(
              stream: streamSnapshot.data!,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _LoadError(
                    message: firebaseErrorMessage(snapshot.error!),
                  );
                }

                final items = snapshot.data ?? const <HrmsNotification>[];
                if (items.isEmpty) {
                  return const _EmptyNotifications();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: VeyraDesign.primary.withValues(
                            alpha: .12,
                          ),
                          child: Icon(
                            _icon(item.type),
                            color: VeyraDesign.primary,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: item.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w900,
                                ),
                              ),
                            ),
                            if (!item.isRead)
                              const CircleAvatar(
                                radius: 4,
                                backgroundColor: VeyraDesign.primary,
                              ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(item.body),
                        ),
                        trailing: _canOpenTarget(item)
                            ? const Icon(Icons.chevron_right_rounded)
                            : null,
                        onTap: () => _openNotification(item),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  static IconData _icon(HrmsNotificationType type) => switch (type) {
    HrmsNotificationType.leaveSubmitted ||
    HrmsNotificationType.leaveApproved ||
    HrmsNotificationType.leaveRejected => Icons.event_available_rounded,
    HrmsNotificationType.claimSubmitted ||
    HrmsNotificationType.claimApproved ||
    HrmsNotificationType.claimRejected ||
    HrmsNotificationType.claimPaid => Icons.receipt_long_rounded,
    HrmsNotificationType.payslipPublished => Icons.description_rounded,
    HrmsNotificationType.employeeInvitation => Icons.person_add_alt_1_rounded,
    HrmsNotificationType.general => Icons.notifications_rounded,
  };

  static bool _canOpenTarget(HrmsNotification item) {
    final target = item.targetType?.trim().toLowerCase();
    if (target != null && target.isNotEmpty) {
      if (_leaveTargets.contains(target) ||
          _claimTargets.contains(target) ||
          _payslipTargets.contains(target)) {
        return true;
      }
    }

    return switch (item.type) {
      HrmsNotificationType.leaveSubmitted ||
      HrmsNotificationType.leaveApproved ||
      HrmsNotificationType.leaveRejected ||
      HrmsNotificationType.claimSubmitted ||
      HrmsNotificationType.claimApproved ||
      HrmsNotificationType.claimRejected ||
      HrmsNotificationType.claimPaid ||
      HrmsNotificationType.payslipPublished => true,
      HrmsNotificationType.employeeInvitation ||
      HrmsNotificationType.general => false,
    };
  }

  static void _openTarget(BuildContext context, HrmsNotification item) {
    final target = item.targetType?.trim().toLowerCase();

    Widget? destination;
    if (target != null && _leaveTargets.contains(target)) {
      destination = const LeaveScreen();
    } else if (target != null && _claimTargets.contains(target)) {
      destination = const ClaimsScreen();
    } else if (target != null && _payslipTargets.contains(target)) {
      destination = const PayslipScreen();
    } else {
      destination = switch (item.type) {
        HrmsNotificationType.leaveSubmitted ||
        HrmsNotificationType.leaveApproved ||
        HrmsNotificationType.leaveRejected => const LeaveScreen(),
        HrmsNotificationType.claimSubmitted ||
        HrmsNotificationType.claimApproved ||
        HrmsNotificationType.claimRejected ||
        HrmsNotificationType.claimPaid => const ClaimsScreen(),
        HrmsNotificationType.payslipPublished => const PayslipScreen(),
        HrmsNotificationType.employeeInvitation ||
        HrmsNotificationType.general => null,
      };
    }

    if (destination != null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => destination!));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${item.title}: ${item.body}')));
  }

  static const _leaveTargets = <String>{
    'leave',
    'leave_request',
    'leaverequest',
    'leave-request',
  };

  static const _claimTargets = <String>{
    'claim',
    'claim_request',
    'claimrequest',
    'claim-request',
    'expense_claim',
  };

  static const _payslipTargets = <String>{
    'payslip',
    'payroll',
    'payroll_payslip',
  };
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 52,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 14),
            Text(
              'You are all caught up.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'New HR updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }
}
